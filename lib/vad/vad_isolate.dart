import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import '../audio/band_levels.dart';
import 'piece.dart';
import 'segmenter.dart';
import 'silero_vad_detector.dart';
import 'vad_event.dart';
import 'vad_message.dart';

/// Runs Silero VAD, the segmenter and the visualizer FFT off the UI isolate.
/// Takes raw 16 kHz PCM16 mic bytes; reports [VadMessage]s.
class VadIsolate {
  VadIsolate._(this._commands, this._inbox, this.messages);

  final SendPort _commands;
  final ReceivePort _inbox;
  final Stream<VadMessage> messages;

  static Future<VadIsolate> spawn(String sileroModel) async {
    final inbox = ReceivePort();
    final isolate = await Isolate.spawn(_main, (
      inbox.sendPort,
      sileroModel,
    ), debugName: 'vad');
    final controller = StreamController<VadMessage>.broadcast();
    final ready = Completer<SendPort>();
    inbox.listen((m) {
      if (m is SendPort) {
        ready.complete(m);
      } else if (m is String) {
        if (!ready.isCompleted) ready.completeError(StateError(m));
      } else if (m is (int, int)) {
        controller.add(TurnEventMessage(TurnEventKind.values[m.$1], m.$2));
      } else if (m is (int, int, bool, TransferableTypedData)) {
        final audio = m.$4.materialize().asFloat32List();
        controller.add(
          PieceMessage(
            Piece(
              seq: m.$1,
              audio: audio,
              kind: PieceKind.values[m.$2],
              isLast: m.$3,
            ),
          ),
        );
      } else if (m is Float32List) {
        controller.add(MicLevels(m));
      }
    });
    try {
      return VadIsolate._(await ready.future, inbox, controller.stream);
    } catch (_) {
      inbox.close();
      isolate.kill();
      rethrow;
    }
  }

  /// Raw PCM16 little-endian mic bytes.
  void addPcm16(Uint8List bytes) =>
      _commands.send(TransferableTypedData.fromList([bytes]));

  /// Starts a new listening session (new turn, sample count from zero).
  void reset() => _commands.send('reset');

  /// Ends the current turn now, as if the silence had run out.
  void forceEndOfTurn() => _commands.send('end');

  void dispose() {
    _commands.send(null);
    _inbox.close();
  }

  static void _main((SendPort, String) args) {
    final (out, model) = args;
    final SileroVadDetector vad;
    try {
      so.initBindings();
      vad = SileroVadDetector(model);
    } catch (e) {
      out.send('VAD load failed: $e');
      return;
    }
    final segmenter = Segmenter(vad);
    final bands = BandLevels(sampleRate: 16000);
    const window = SileroVadDetector.windowSize;
    final pending = Float32List(window);
    var filled = 0;
    var processed = 0;
    var sessionStart = 0;

    segmenter.events.listen((e) {
      final kind = switch (e) {
        SpeechStart() => TurnEventKind.speechStart,
        ShortPause() => TurnEventKind.shortPause,
        EndOfTurn() => TurnEventKind.endOfTurn,
      };
      out.send((kind.index, e.lastVoiceSample - sessionStart));
    });
    segmenter.pieces.listen((p) {
      out.send((
        p.seq,
        p.kind.index,
        p.isLast,
        TransferableTypedData.fromList([p.audio]),
      ));
    });

    final inbox = ReceivePort();
    out.send(inbox.sendPort);
    inbox.listen((m) {
      if (m == null) {
        vad.dispose();
        inbox.close();
      } else if (m == 'reset') {
        segmenter.reset();
        vad.reset();
        filled = 0;
        sessionStart = processed;
      } else if (m == 'end') {
        segmenter.forceEndOfTurn();
      } else if (m is TransferableTypedData) {
        final bytes = m.materialize().asUint8List();
        final data = ByteData.sublistView(bytes);
        for (var i = 0; i + 1 < bytes.length; i += 2) {
          pending[filled++] = data.getInt16(i, Endian.little) / 32768.0;
          if (filled == window) {
            final frame = Float32List.fromList(pending);
            filled = 0;
            processed += window;
            segmenter.addFrame(frame);
            out.send(bands.of(frame));
          }
        }
      }
    });
  }
}
