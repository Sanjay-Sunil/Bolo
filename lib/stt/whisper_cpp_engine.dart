import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'stt_engine.dart';
import 'stt_result.dart';

typedef _InitC = Pointer<Void> Function(Pointer<Utf8>);
typedef _FreeC = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);
typedef _TranscribeC = Int32 Function(
  Pointer<Void>,
  Pointer<Float>,
  Int32,
  Pointer<Utf8>,
  Int32,
  Int32,
  Pointer<Uint8>,
  Int32,
  Pointer<Float>,
  Pointer<Int32>,
);
typedef _TranscribeDart = int Function(
  Pointer<Void>,
  Pointer<Float>,
  int,
  Pointer<Utf8>,
  int,
  int,
  Pointer<Uint8>,
  int,
  Pointer<Float>,
  Pointer<Int32>,
);

class _Bindings {
  _Bindings._(DynamicLibrary lib)
    : init = lib.lookupFunction<_InitC, _InitC>('bw_init'),
      free = lib.lookupFunction<_FreeC, _FreeDart>('bw_free'),
      transcribe = lib.lookupFunction<_TranscribeC, _TranscribeDart>(
        'bw_transcribe',
      );

  static final instance = _Bindings._(
    DynamicLibrary.open('libbolo_whisper.so'),
  );

  final _InitC init;
  final _FreeDart free;
  final _TranscribeDart transcribe;
}

/// whisper.cpp engine. Calls block, so use it only inside the STT isolate.
class WhisperCppEngine implements SttEngine {
  WhisperCppEngine._(this._ctx, this.threads, this.limitAudioWindow)
    : minAudioCtx = defaultMinAudioCtx;

  /// Loads a ggml model. Returns null if the file cannot be loaded.
  static WhisperCppEngine? load(
    String modelPath, {
    required int threads,
    bool limitAudioWindow = true,
  }) {
    final path = modelPath.toNativeUtf8();
    try {
      final ctx = _Bindings.instance.init(path);
      if (ctx == nullptr) return null;
      return WhisperCppEngine._(ctx, threads, limitAudioWindow);
    } finally {
      calloc.free(path);
    }
  }

  /// Re-attaches to a context created in another isolate.
  WhisperCppEngine.fromAddress(
    int address, {
    required this.threads,
    this.limitAudioWindow = true,
    this.minAudioCtx = defaultMinAudioCtx,
  }) : _ctx = Pointer<Void>.fromAddress(address);

  static const _sampleRate = 16000;
  static const _maxAudioCtx = 1500;
  static const _outCap = 4096;

  /// Smallest encoder window (10 s). At 448 frames or less Swift's Hinglish
  /// output falls apart; 500 matched the full 30 s window on every test clip.
  static const defaultMinAudioCtx = 500;

  final Pointer<Void> _ctx;
  final int threads;
  bool limitAudioWindow;
  int minAudioCtx;
  int lastDecodeMs = 0;

  int get address => _ctx.address;

  /// Encoder frames for [samples] of audio (50 per second) plus headroom.
  static int audioCtxFor(int samples, {int minFrames = defaultMinAudioCtx}) {
    final frames = (samples / _sampleRate * 50).ceil() + 64;
    return frames.clamp(minFrames, _maxAudioCtx);
  }

  @override
  Future<SttResult> decode(Float32List audio, {String? prompt}) async =>
      decodeSync(audio, prompt: prompt);

  SttResult decodeSync(Float32List audio, {String? prompt}) {
    final pcm = calloc<Float>(audio.length);
    final promptPtr = (prompt ?? '').toNativeUtf8();
    final out = calloc<Uint8>(_outCap);
    final logProb = calloc<Float>();
    final ms = calloc<Int32>();
    try {
      pcm.asTypedList(audio.length).setAll(0, audio);
      final rc = _Bindings.instance.transcribe(
        _ctx,
        pcm,
        audio.length,
        promptPtr,
        threads,
        limitAudioWindow
            ? audioCtxFor(audio.length, minFrames: minAudioCtx)
            : 0,
        out,
        _outCap,
        logProb,
        ms,
      );
      if (rc != 0) throw StateError('whisper decode failed ($rc)');
      lastDecodeMs = ms.value;
      return SttResult(
        text: out.cast<Utf8>().toDartString().trim(),
        avgLogProb: logProb.value,
      );
    } finally {
      calloc
        ..free(pcm)
        ..free(promptPtr)
        ..free(out)
        ..free(logProb)
        ..free(ms);
    }
  }

  void dispose() => _Bindings.instance.free(_ctx);
}
