import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'stt_engine.dart';
import 'stt_result.dart';
import 'whisper_cpp_engine.dart';

/// Long-lived isolate that owns the Whisper model; decodes run one at a time.
class SttIsolate implements SttEngine {
  SttIsolate._(this._requests, this._inbox);

  final SendPort _requests;
  final ReceivePort _inbox;
  final _pending = <int, Completer<SttResult>>{};
  int _nextId = 0;

  /// Wall time of the last decode inside the isolate.
  int lastDecodeMs = 0;

  static Future<SttIsolate> spawn(String model, {required int threads}) async {
    final inbox = ReceivePort();
    final isolate = await Isolate.spawn(_main, (
      inbox.sendPort,
      model,
      threads,
    ), debugName: 'stt');
    final ready = Completer<SendPort>();
    late final SttIsolate stt;
    inbox.listen((m) {
      if (m is SendPort) {
        ready.complete(m);
      } else if (m is (int, String, double, int)) {
        stt.lastDecodeMs = m.$4;
        stt._pending
            .remove(m.$1)
            ?.complete(SttResult(text: m.$2, avgLogProb: m.$3));
      } else if (m is (int, String)) {
        stt._pending.remove(m.$1)?.completeError(StateError(m.$2));
      } else if (m is String && !ready.isCompleted) {
        ready.completeError(StateError(m));
      }
    });
    try {
      stt = SttIsolate._(await ready.future, inbox);
    } catch (_) {
      inbox.close();
      isolate.kill();
      rethrow;
    }
    return stt;
  }

  @override
  Future<SttResult> decode(Float32List audio, {String? prompt}) {
    final id = _nextId++;
    final done = Completer<SttResult>();
    _pending[id] = done;
    _requests.send((id, TransferableTypedData.fromList([audio]), prompt));
    return done.future;
  }

  void dispose() {
    _requests.send(null);
    _inbox.close();
    for (final p in _pending.values) {
      p.completeError(StateError('STT isolate closed'));
    }
    _pending.clear();
  }

  static void _main((SendPort, String, int) args) {
    final (out, model, threads) = args;
    final engine = WhisperCppEngine.load(model, threads: threads);
    if (engine == null) {
      out.send('Whisper model failed to load');
      return;
    }
    final inbox = ReceivePort();
    out.send(inbox.sendPort);
    inbox.listen((m) {
      if (m == null) {
        engine.dispose();
        inbox.close();
        return;
      }
      final (id, data, prompt) = m as (int, TransferableTypedData, String?);
      try {
        final audio = data.materialize().asFloat32List();
        final r = engine.decodeSync(audio, prompt: prompt);
        out.send((id, r.text, r.avgLogProb, engine.lastDecodeMs));
      } catch (e) {
        out.send((id, '$e'));
      }
    });
  }
}
