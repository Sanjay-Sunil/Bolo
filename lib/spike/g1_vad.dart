// Gate G1: Silero VAD via sherpa-onnx on the phone microphone.
// Run: flutter run --release -t lib/spike/g1_vad.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import 'spike_models.dart';

void main() => runApp(const MaterialApp(home: G1Page()));

class G1Page extends StatefulWidget {
  const G1Page({super.key});

  @override
  State<G1Page> createState() => _G1PageState();
}

class _G1PageState extends State<G1Page> {
  static const _window = 512;
  final _recorder = AudioRecorder();
  so.VoiceActivityDetector? _vad;
  StreamSubscription<Uint8List>? _sub;
  final _pending = <double>[];

  String _status = 'Tap start';
  bool _speech = false;
  int _windows = 0;
  double _sumMs = 0;
  double _maxMs = 0;
  int _segments = 0;
  double _lastSegmentSec = 0;
  int _loadMs = 0;
  double _lastFlipSec = 0;

  Future<void> _start() async {
    if (!await Permission.microphone.request().isGranted) {
      setState(() => _status = 'Mic permission denied');
      return;
    }
    if (_vad == null) {
      setState(() => _status = 'Loading model...');
      final String modelPath;
      try {
        modelPath = await ensureModel(
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad_v5.onnx',
          'silero_vad_v5.onnx',
        );
      } catch (e) {
        setState(() => _status = 'Model error: $e');
        return;
      }
      final sw = Stopwatch()..start();
      so.initBindings();
      final config = so.VadModelConfig(
        sileroVad: so.SileroVadModelConfig(
          model: modelPath,
          minSilenceDuration: 0.2,
          minSpeechDuration: 0.25,
          maxSpeechDuration: 20,
        ),
        numThreads: 1,
        debug: false,
      );
      _vad = so.VoiceActivityDetector(config: config, bufferSizeInSeconds: 30);
      _loadMs = sw.elapsedMilliseconds;
    }
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
    _sub = stream.listen(_onPcm);
    setState(() => _status = 'Listening');
  }

  void _onPcm(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      _pending.add(data.getInt16(i, Endian.little) / 32768.0);
    }
    var changed = false;
    while (_pending.length >= _window) {
      final frame = Float32List.fromList(_pending.sublist(0, _window));
      _pending.removeRange(0, _window);
      final sw = Stopwatch()..start();
      _vad!.acceptWaveform(frame);
      final speech = _vad!.isDetected();
      final ms = sw.elapsedMicroseconds / 1000.0;
      _windows++;
      _sumMs += ms;
      if (ms > _maxMs) _maxMs = ms;
      while (!_vad!.isEmpty()) {
        final seg = _vad!.front();
        _segments++;
        _lastSegmentSec = seg.samples.length / 16000.0;
        debugPrint('G1 segment ${_lastSegmentSec.toStringAsFixed(2)}s');
        _vad!.pop();
      }
      if (speech != _speech) {
        final t = _windows * _window / 16000.0;
        final gap = t - _lastFlipSec;
        debugPrint(
          'G1 ${speech ? 'SPEECH' : 'silence'} at '
          '${t.toStringAsFixed(2)}s after ${gap.toStringAsFixed(2)}s',
        );
        _lastFlipSec = t;
      }
      _speech = speech;
      changed = true;
    }
    if (changed) setState(() {});
  }

  Future<void> _stop() async {
    final avg = _windows == 0 ? 0 : _sumMs / _windows;
    debugPrint(
      'G1 summary load=${_loadMs}ms windows=$_windows '
      'avg=${avg.toStringAsFixed(2)}ms max=${_maxMs.toStringAsFixed(2)}ms '
      'segments=$_segments',
    );
    await _sub?.cancel();
    await _recorder.stop();
    setState(() => _status = 'Stopped');
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    _vad?.free();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avg = _windows == 0 ? 0 : _sumMs / _windows;
    return Scaffold(
      backgroundColor: _speech ? Colors.white : Colors.black,
      body: DefaultTextStyle(
        style: TextStyle(
          color: _speech ? Colors.black : Colors.white,
          fontSize: 18,
          fontFamily: 'monospace',
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _speech ? 'SPEECH' : 'silence',
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 24),
                Text('status      $_status'),
                Text('model load  $_loadMs ms'),
                Text('windows     $_windows (32 ms each)'),
                Text('avg/window  ${avg.toStringAsFixed(2)} ms'),
                Text('max/window  ${_maxMs.toStringAsFixed(2)} ms'),
                Text('segments    $_segments'),
                Text('last seg    ${_lastSegmentSec.toStringAsFixed(2)} s'),
                const Spacer(),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _start,
                      child: const Text('Start'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(onPressed: _stop, child: const Text('Stop')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
