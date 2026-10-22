import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../app/app_clock.dart';
import '../app/model_manager.dart';
import '../app/thread_budget.dart';
import '../audio/audio_player.dart';
import '../llm/chat_message.dart';
import '../llm/llm_client.dart';
import '../llm/llm_provider.dart';
import '../llm/llm_stream_exception.dart';
import '../pipeline/turn_metrics.dart';
import '../stt/stt_isolate.dart';
import '../stt/turn_transcriber.dart';
import '../text/roman_hinglish.dart';
import '../tts/phrase_splitter.dart';
import '../tts/tts_isolate.dart';
import '../vad/vad_isolate.dart';
import '../vad/vad_message.dart';
import 'chat_entry.dart';
import 'conversation_phase.dart';
import 'spoken_phrase.dart';

/// Runs the hands-free loop: listen → end of turn → transcript → streamed
/// reply spoken phrase by phrase → listen again. Ends after [idleTimeout]
/// without speech, or when the user taps.
class ConversationController {
  ConversationController();

  static const idleTimeout = Duration(seconds: 8);
  static const maxTurn = Duration(seconds: 25);
  static const _sampleRate = 16000;
  static final _sentenceEnd = RegExp(r'[.?!।]["”’)]*\s*$');

  final phase = ValueNotifier(ConversationPhase.loading);

  /// What the user is saying (live), then their final words for the turn.
  final userText = ValueNotifier('');

  /// Reply phrases as they are scheduled to play.
  final reply = ValueNotifier<List<SpokenPhrase>>(const []);
  final history = ValueNotifier<List<ChatEntry>>(const []);

  /// Short status or error line under the stage.
  final status = ValueNotifier('');

  /// Latency breakdown of the last turn.
  final metrics = ValueNotifier('');

  /// Latest mic visualizer levels (read every frame by the UI).
  Float32List micLevels = Float32List(7);

  final _models = ModelManager();

  /// First-run download progress (0..1), null when not downloading.
  ValueListenable<double?> get downloadProgress => _models.progress;

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _llmHistory = <ChatMessage>[];
  VadIsolate? _vad;
  SttIsolate? _stt;
  TtsIsolate? _tts;
  LlmClient? _llm;
  TurnTranscriber? _transcriber;
  StreamSubscription<Uint8List>? _mic;
  StreamSubscription<VadMessage>? _vadSub;
  StreamSubscription<String>? _liveSub;
  Timer? _idleTimer;
  Timer? _maxTurnTimer;

  bool _active = false;
  bool _micOpen = false;
  bool _heardSpeech = false;
  int _turn = 0;
  Duration _micStart = Duration.zero;
  TurnMetrics _metrics = const TurnMetrics();

  bool get active => _active;

  Future<void> init() async {
    try {
      final key = LlmProvider.groq.buildKey;
      if (key.isNotEmpty) {
        _llm = LlmClient(provider: LlmProvider.groq, apiKey: key);
      }
      final models = await _models.ensure();
      final threads = inferenceThreads();
      final sw = Stopwatch()..start();
      final loaded = await Future.wait([
        VadIsolate.spawn(models.silero),
        SttIsolate.spawn(models.whisper, threads: threads),
        TtsIsolate.spawn(
          hindi: models.hindiVoice,
          english: models.englishVoice,
          threads: threads,
        ),
      ]);
      _vad = loaded[0] as VadIsolate;
      _stt = loaded[1] as SttIsolate;
      _tts = loaded[2] as TtsIsolate;
      _transcriber = TurnTranscriber(_stt!.decode);
      _vadSub = _vad!.messages.listen(_onVad);
      _liveSub = _transcriber!.live.listen((text) {
        if (phase.value == ConversationPhase.listening ||
            phase.value == ConversationPhase.thinking) {
          userText.value = text;
        }
      });
      debugPrint('BOLO models loaded in ${sw.elapsedMilliseconds} ms');
      status.value = _llm == null ? 'No Groq key in .env' : '';
      phase.value = ConversationPhase.idle;
    } catch (e) {
      debugPrint('BOLO load error: $e');
      status.value = e is SocketException || e is HttpException
          ? 'Couldn\'t download the models. Check the internet and reopen.'
          : 'Couldn\'t load models: $e';
      phase.value = ConversationPhase.failed;
    }
  }

  /// Mic button: start a conversation, or stop the one running.
  Future<void> toggle() async {
    switch (phase.value) {
      case ConversationPhase.idle:
        await start();
      case ConversationPhase.listening ||
          ConversationPhase.thinking ||
          ConversationPhase.speaking:
        await stop();
      default:
    }
  }

  Future<void> start() async {
    if (phase.value != ConversationPhase.idle) return;
    if (!await Permission.microphone.request().isGranted) {
      status.value = 'Microphone permission is needed';
      return;
    }
    _active = true;
    status.value = '';
    await _listen();
  }

  Future<void> stop() async {
    _active = false;
    _turn++;
    _cancelTimers();
    await _closeMic();
    await _player.stop();
    _transcriber?.reset();
    phase.value = ConversationPhase.idle;
  }

  /// Typing fallback: answers [text] as if it had been spoken.
  Future<void> sendTyped(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    if (phase.value == ConversationPhase.thinking ||
        phase.value == ConversationPhase.speaking) {
      return;
    }
    _turn++;
    _cancelTimers();
    await _closeMic();
    _transcriber?.reset();
    userText.value = t;
    reply.value = const [];
    _metrics = const TurnMetrics();
    unawaited(_respond(t, typed: true));
  }

  Future<void> _listen() async {
    final turn = ++_turn;
    _cancelTimers();
    _heardSpeech = false;
    _metrics = const TurnMetrics();
    _transcriber!.reset();
    _vad!.reset();
    phase.value = ConversationPhase.listening;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
        ),
      ),
    );
    if (turn != _turn) {
      await _recorder.stop();
      return;
    }
    _micStart = now;
    _micOpen = true;
    _mic = stream.listen((bytes) {
      if (_micOpen) _vad!.addPcm16(bytes);
    });
    _idleTimer = Timer(idleTimeout, () {
      if (turn == _turn && !_heardSpeech) unawaited(stop());
    });
  }

  Future<void> _closeMic() async {
    if (!_micOpen && _mic == null) return;
    _micOpen = false;
    micLevels = Float32List(micLevels.length);
    await _mic?.cancel();
    _mic = null;
    await _recorder.stop();
  }

  void _cancelTimers() {
    _idleTimer?.cancel();
    _maxTurnTimer?.cancel();
  }

  Duration _sampleTime(int sample) =>
      _micStart + Duration(microseconds: sample * 1000000 ~/ _sampleRate);

  void _onVad(VadMessage m) {
    if (!_micOpen) return;
    switch (m) {
      case MicLevels(:final levels):
        micLevels = levels;
      case PieceMessage(:final piece):
        _transcriber!.add(piece);
      case TurnEventMessage(:final kind, :final lastVoiceSample):
        switch (kind) {
          case TurnEventKind.speechStart:
            _heardSpeech = true;
            _idleTimer?.cancel();
            _metrics = _metrics.mark(
              TurnEvent.speechStart,
              _sampleTime(lastVoiceSample),
            );
            userText.value = '';
            reply.value = const [];
            final turn = _turn;
            _maxTurnTimer = Timer(maxTurn, () {
              if (turn == _turn) _vad!.forceEndOfTurn();
            });
          case TurnEventKind.shortPause:
            break;
          case TurnEventKind.endOfTurn:
            _metrics = _metrics
                .mark(TurnEvent.lastVoice, _sampleTime(lastVoiceSample))
                .mark(TurnEvent.endOfTurn, now);
            _maxTurnTimer?.cancel();
            phase.value = ConversationPhase.thinking;
            // The last piece is still on its way from the VAD isolate.
            scheduleMicrotask(() => unawaited(_finishTurn(_turn)));
        }
    }
  }

  Future<void> _finishTurn(int turn) async {
    // Let the final piece arrive before the mic stops feeding the VAD.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _closeMic();
    final result = await _transcriber!.finalResult;
    if (turn != _turn) return;
    _metrics = _metrics.mark(TurnEvent.sttFinal, now);
    final text = result.text.trim();
    if (text.isEmpty) {
      if (_active) await _listen();
      return;
    }
    userText.value = text;
    await _respond(text, confidence: math.exp(result.avgLogProb));
  }

  Future<void> _respond(
    String text, {
    double? confidence,
    bool typed = false,
  }) async {
    final turn = _turn;
    final llm = _llm;
    if (llm == null) {
      status.value = 'No Groq key: add GROQ_API_KEY to .env and rebuild';
      phase.value = ConversationPhase.idle;
      return;
    }
    phase.value = ConversationPhase.thinking;
    reply.value = const [];
    _metrics = _metrics.mark(TurnEvent.llmRequest, now);
    final spoken = StringBuffer();
    var chain = Future<void>.value();
    var firstPhrase = true;
    try {
      final tokens = llm.streamReply(_llmHistory, text).map((t) {
        if (_metrics[TurnEvent.llmFirstToken] == null) {
          _metrics = _metrics.mark(TurnEvent.llmFirstToken, now);
        }
        return t;
      });
      await for (final phrase in PhraseSplitter().split(tokens)) {
        if (turn != _turn) break;
        final capitalize =
            spoken.isEmpty || _sentenceEnd.hasMatch(spoken.toString());
        spoken.write(spoken.isEmpty ? phrase : ' $phrase');
        final synth = _tts!.synthesize(phrase);
        chain = chain.then((_) async {
          final r = await synth;
          if (turn != _turn) return;
          if (firstPhrase) {
            firstPhrase = false;
            _metrics = _metrics.mark(TurnEvent.firstPhraseReady, now);
          }
          final start = await _player.enqueue(
            r.pcm16,
            r.sampleRate,
            r.duration,
          );
          if (_metrics[TurnEvent.firstAudio] == null) {
            _metrics = _metrics.mark(TurnEvent.firstAudio, start);
            phase.value = ConversationPhase.speaking;
          }
          reply.value = [
            ...reply.value,
            SpokenPhrase(
              text: romanHinglish(phrase, capitalize: capitalize),
              start: start,
              duration: r.duration,
              levels: r.levels,
              levelWindow: r.levelWindow,
              sampleRate: r.sampleRate,
            ),
          ];
        });
      }
      await chain;
    } on LlmStreamException catch (e) {
      debugPrint('BOLO LLM error: $e');
      status.value = 'Couldn\'t reach Groq: ${e.message}';
    } catch (e) {
      debugPrint('BOLO turn error: $e');
      status.value = 'Something went wrong: $e';
    }
    if (turn != _turn) return;

    final remaining = _player.endsAt - now;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (turn != _turn) return;
    _metrics = _metrics.mark(TurnEvent.lastAudio, now);

    final answer = spoken.toString();
    if (answer.isNotEmpty) {
      _llmHistory
        ..add(ChatMessage.user(text))
        ..add(ChatMessage.assistant(answer));
      final summary = _metrics.summary();
      metrics.value = summary;
      debugPrint('BOLO turn: "$text" -> "$answer" | $summary');
      history.value = [
        ...history.value,
        ChatEntry(
          user: text,
          reply: romanHinglish(answer),
          metrics: summary,
          confidence: confidence,
          typed: typed,
        ),
      ];
    }
    if (_active) {
      await _listen();
    } else {
      phase.value = ConversationPhase.idle;
    }
  }

  Future<void> dispose() async {
    _active = false;
    _turn++;
    _cancelTimers();
    await _vadSub?.cancel();
    await _liveSub?.cancel();
    await _closeMic();
    await _player.stop();
    _recorder.dispose();
    _vad?.dispose();
    _stt?.dispose();
    _tts?.dispose();
    _llm?.close();
    _models.dispose();
    await _transcriber?.close();
  }
}
