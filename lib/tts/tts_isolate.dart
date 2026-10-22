import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import 'piper_engine.dart';
import 'piper_voice_files.dart';
import 'text_normalizer.dart';
import 'tts_audio.dart';
import 'tts_result.dart';
import 'voice.dart';

/// Long-lived isolate that owns the TTS engine. Requests run one at a time,
/// in order; PCM comes back without copying.
class TtsIsolate {
  TtsIsolate._(this._requests, this._responses);

  final SendPort _requests;
  final ReceivePort _responses;
  final _pending = <int, Completer<TtsResult>>{};
  int _nextId = 0;

  static Future<TtsIsolate> spawn({
    required PiperVoiceFiles hindi,
    required PiperVoiceFiles english,
    required int threads,
  }) async {
    final responses = ReceivePort();
    final isolate = await Isolate.spawn(_main, (
      responses.sendPort,
      hindi,
      english,
      threads,
    ), debugName: 'tts');
    final ready = Completer<SendPort>();
    late final TtsIsolate tts;
    responses.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
      } else if (message is (int, TransferableTypedData, int, int)) {
        final (id, pcm, sampleRate, ms) = message;
        final samples = pcm.materialize().asFloat32List();
        tts._pending
            .remove(id)
            ?.complete(TtsResult(TtsAudio(samples, sampleRate), ms));
      } else if (message is (int, String)) {
        final (id, error) = message;
        tts._pending.remove(id)?.completeError(StateError(error));
      } else if (message is String && !ready.isCompleted) {
        ready.completeError(StateError(message));
      }
    });
    try {
      tts = TtsIsolate._(await ready.future, responses);
    } catch (_) {
      responses.close();
      isolate.kill();
      rethrow;
    }
    return tts;
  }

  Future<TtsResult> synthesize(String phrase) {
    final id = _nextId++;
    final done = Completer<TtsResult>();
    _pending[id] = done;
    _requests.send((id, phrase));
    return done.future;
  }

  void dispose() {
    _requests.send(null);
    _responses.close();
    for (final p in _pending.values) {
      p.completeError(StateError('TTS isolate closed'));
    }
    _pending.clear();
  }

  static void _main((SendPort, PiperVoiceFiles, PiperVoiceFiles, int) args) {
    final (out, hindi, english, threads) = args;
    final PiperEngine engine;
    try {
      so.initBindings();
      engine = PiperEngine(hindi: hindi, english: english, threads: threads);
    } catch (e) {
      out.send('TTS load failed: $e');
      return;
    }
    final inbox = ReceivePort();
    out.send(inbox.sendPort);
    final sw = Stopwatch();
    inbox.listen((message) {
      if (message == null) {
        engine.dispose();
        inbox.close();
        return;
      }
      final (id, phrase) = message as (int, String);
      try {
        sw
          ..reset()
          ..start();
        final voice = voiceFor(phrase);
        final audio = engine.synthesize(normalize(phrase, voice), voice);
        final pcm = TransferableTypedData.fromList([
          Float32List.fromList(audio.samples),
        ]);
        out.send((id, pcm, audio.sampleRate, sw.elapsedMilliseconds));
      } catch (e) {
        out.send((id, '$e'));
      }
    });
  }
}
