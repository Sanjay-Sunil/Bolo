import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../app/dev_model_store.dart';
import '../app/thread_budget.dart';
import '../llm/chat_message.dart';
import '../llm/llm_client.dart';
import '../llm/llm_provider.dart';
import '../stt/whisper_cpp_engine.dart';
import '../tts/piper_voice_files.dart';
import '../tts/tts_audio.dart';
import '../tts/tts_isolate.dart';

/// Phase 2 walking skeleton: tap to record, tap to stop, then whole-clip STT,
/// whole LLM reply, whole-reply TTS and playback. Later phases replace each
/// stage with its streaming version.
class SkeletonPage extends StatefulWidget {
  const SkeletonPage({super.key});

  @override
  State<SkeletonPage> createState() => _SkeletonPageState();
}

enum _Stage { loading, idle, recording, working, error }

class _SkeletonPageState extends State<SkeletonPage> {
  static const _maxSeconds = 28;

  final _recorder = AudioRecorder();
  final _history = <ChatMessage>[];
  final _lines = <(String, bool)>[];
  final _pcm = BytesBuilder(copy: false);
  final int _threads = inferenceThreads();
  StreamSubscription<Uint8List>? _mic;
  int? _whisper;
  TtsIsolate? _tts;
  LlmClient? _llm;
  _Stage _stage = _Stage.loading;
  String _status = 'Loading models…';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _add(String text, {bool user = false}) {
    debugPrint('P2 ${user ? 'user' : 'agent'}: $text');
    setState(() => _lines.add((text, user)));
  }

  Future<void> _load() async {
    try {
      final key = LlmProvider.groq.buildKey;
      if (key.isNotEmpty) {
        _llm = LlmClient(provider: LlmProvider.groq, apiKey: key);
      }
      final store = await DevModelStore.open();
      final model = await store.file('ggml-swift-q8_0.bin');
      final hi = await store.pack('piper-hi');
      final en = await store.pack('piper-en-lessac');
      final threads = _threads;
      final sw = Stopwatch()..start();
      _whisper = await _loadWhisper(model, threads);
      if (_whisper == null) throw StateError('Whisper model failed to load');
      _tts = await TtsIsolate.spawn(
        hindi: PiperVoiceFiles(
          model: '$hi/hi_IN-priyamvada-medium.onnx',
          tokens: '$hi/tokens.txt',
          espeakData: '$hi/espeak-ng-data',
        ),
        english: PiperVoiceFiles(
          model: '$en/model.onnx',
          tokens: '$en/tokens.txt',
          espeakData: '$en/espeak-ng-data',
        ),
        threads: threads,
      );
      debugPrint('P2 models loaded in ${sw.elapsedMilliseconds} ms');
      setState(() {
        _stage = _Stage.idle;
        _status = 'Tap the mic and speak';
      });
    } catch (e) {
      debugPrint('P2 load error: $e');
      setState(() {
        _stage = _Stage.error;
        _status = '$e';
      });
    }
  }

  Future<void> _onMic() async {
    switch (_stage) {
      case _Stage.idle:
        await _startRecording();
      case _Stage.recording:
        await _stopAndRespond();
      default:
    }
  }

  Future<void> _startRecording() async {
    if (!await Permission.microphone.request().isGranted) {
      setState(() => _status = 'Microphone permission denied');
      return;
    }
    _pcm.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
        ),
      ),
    );
    _mic = stream.listen((bytes) {
      _pcm.add(bytes);
      if (_pcm.length >= _maxSeconds * 32000) _stopAndRespond();
    });
    setState(() {
      _stage = _Stage.recording;
      _status = 'Listening… tap to stop';
    });
  }

  Future<void> _stopAndRespond() async {
    if (_stage != _Stage.recording) return;
    final total = Stopwatch()..start();
    setState(() {
      _stage = _Stage.working;
      _status = 'Transcribing…';
    });
    await _mic?.cancel();
    await _recorder.stop();
    final audio = _toFloat(_pcm.takeBytes());

    try {
      final stt = await _transcribe(_whisper!, _threads, audio);
      final sttMs = total.elapsedMilliseconds;
      final text = stt.$1;
      if (text.isEmpty) {
        _finish('Didn\'t catch that, try again');
        return;
      }
      _add(text, user: true);
      setState(() => _status = 'Thinking…');

      final llm = _llm;
      if (llm == null) {
        _finish('No Groq key: add GROQ_API_KEY to .env and rebuild');
        return;
      }
      final llmStart = total.elapsedMilliseconds;
      int? firstToken;
      final reply = StringBuffer();
      await for (final chunk in llm.streamReply(_history, text)) {
        firstToken ??= total.elapsedMilliseconds - llmStart;
        reply.write(chunk);
      }
      final llmMs = total.elapsedMilliseconds - llmStart;
      final answer = reply.toString().trim();
      _history
        ..add(ChatMessage.user(text))
        ..add(ChatMessage.assistant(answer));
      _add(answer);
      setState(() => _status = 'Speaking…');

      final tts = await _tts!.synthesize(answer);
      final ttsMs = total.elapsedMilliseconds - llmStart - llmMs;
      await _play(tts.audio);
      final firstAudio = total.elapsedMilliseconds;
      final secs = (audio.length / 16000).toStringAsFixed(1);
      final metrics =
          'clip ${secs}s · STT $sttMs (decode ${stt.$2}) · '
          'LLM ${firstToken ?? 0}/$llmMs · TTS $ttsMs (synth ${tts.synthMs}) · '
          'total $firstAudio ms';
      debugPrint('P2 metrics: $metrics');
      _finish(metrics);
    } catch (e) {
      debugPrint('P2 turn error: $e');
      _finish('Error: $e');
    }
  }

  // Kept out of async methods so the isolate closures capture only their
  // arguments, not the caller's (unsendable) async state.
  static Future<int?> _loadWhisper(String model, int threads) => Isolate.run(
    () => WhisperCppEngine.load(model, threads: threads)?.address,
  );

  static Future<(String, int)> _transcribe(
    int address,
    int threads,
    Float32List audio,
  ) => Isolate.run(() {
    final e = WhisperCppEngine.fromAddress(address, threads: threads);
    final r = e.decodeSync(audio);
    return (r.text, e.lastDecodeMs);
  });

  void _finish(String status) => setState(() {
    _stage = _Stage.idle;
    _status = status;
  });

  static Float32List _toFloat(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final out = Float32List(bytes.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  Future<void> _play(TtsAudio audio) async {
    await FlutterPcmSound.release();
    await FlutterPcmSound.setup(sampleRate: audio.sampleRate, channelCount: 1);
    final pcm = ByteData(audio.samples.length * 2);
    for (var i = 0; i < audio.samples.length; i++) {
      pcm.setInt16(
        i * 2,
        (audio.samples[i].clamp(-1.0, 1.0) * 32767).round(),
        Endian.little,
      );
    }
    await FlutterPcmSound.feed(PcmArrayInt16(bytes: pcm));
  }

  @override
  void dispose() {
    _mic?.cancel();
    _recorder.dispose();
    _tts?.dispose();
    _llm?.close();
    if (_whisper != null) {
      WhisperCppEngine.fromAddress(_whisper!, threads: 1).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = _stage == _Stage.recording;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final (text, user) in _lines)
                    Align(
                      alignment: user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: user ? Colors.white : Colors.black,
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: user ? Colors.black : Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: IconButton.filled(
                iconSize: 40,
                style: IconButton.styleFrom(
                  backgroundColor: recording ? Colors.white : Colors.black,
                  foregroundColor: recording ? Colors.black : Colors.white,
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.all(20),
                ),
                onPressed: _stage == _Stage.idle || recording ? _onMic : null,
                icon: Icon(recording ? Icons.stop : Icons.mic),
                tooltip: recording ? 'Stop' : 'Speak',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
