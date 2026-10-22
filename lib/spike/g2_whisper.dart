// Gates G2 + G4: Swift (whisper.cpp) on the phone, q5_1 vs q8_0, full vs limited audio window.
// Models are served from the laptop: `adb reverse tcp:8765 tcp:8765` + `python -m http.server 8765` in models/.
// Run: flutter run --release -t lib/spike/g2_whisper.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import '../app/thread_budget.dart';
import '../stt/whisper_cpp_engine.dart';
import 'spike_models.dart';

void main() => runApp(const MaterialApp(home: G2Page()));

const _laptop = 'http://127.0.0.1:8765';
const _vadUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad_v5.onnx';
const _models = ['q5_1', 'q8_0'];

class G2Page extends StatefulWidget {
  const G2Page({super.key});

  @override
  State<G2Page> createState() => _G2PageState();
}

class _G2PageState extends State<G2Page> {
  static const _window = 512;
  final _recorder = AudioRecorder();
  final _engines = <String, WhisperCppEngine>{};
  final _log = <String>[];
  final _pending = <double>[];
  final _queue = <Float32List>[];
  so.VoiceActivityDetector? _vad;
  StreamSubscription<Uint8List>? _sub;
  bool _busy = false;
  bool _speech = false;
  int _utterance = 0;
  final int _threads = inferenceThreads();

  void _say(String line) {
    debugPrint('G2 $line');
    setState(() {
      _log.insert(0, line);
      if (_log.length > 40) _log.removeLast();
    });
  }

  int get _rssMb => ProcessInfo.currentRss ~/ (1024 * 1024);

  Future<void> _load() async {
    if (_vad != null) return;
    _say(
      'threads=$_threads cores=${Platform.numberOfProcessors} rss=${_rssMb}MB',
    );
    so.initBindings();
    _vad = so.VoiceActivityDetector(
      config: so.VadModelConfig(
        sileroVad: so.SileroVadModelConfig(
          model: await ensureModel(_vadUrl, 'silero_vad_v5.onnx'),
          minSilenceDuration: 0.4,
          minSpeechDuration: 0.25,
          maxSpeechDuration: 20,
        ),
        debug: false,
      ),
      bufferSizeInSeconds: 30,
    );
    for (final q in _models) {
      _say('downloading $q ...');
      final path = await ensureModel(
        '$_laptop/ggml-swift-$q.bin',
        'ggml-swift-$q.bin',
      );
      final before = _rssMb;
      final sw = Stopwatch()..start();
      final engine = WhisperCppEngine.load(path, threads: _threads);
      if (engine == null) {
        _say('$q FAILED to load');
        continue;
      }
      _engines[q] = engine;
      _say(
        '$q loaded in ${sw.elapsedMilliseconds} ms, '
        'rss +${_rssMb - before}MB (now ${_rssMb}MB)',
      );
    }
    for (final e in _engines.entries) {
      final r = await _decode(e.value, Float32List(16000), true);
      _say('${e.key} warm-up ${r.$2} ms');
    }
  }

  Future<void> _start() async {
    if (!await Permission.microphone.request().isGranted) {
      _say('mic permission denied');
      return;
    }
    try {
      await _load();
    } catch (e) {
      _say('load error: $e');
      return;
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
    _say('listening: say a test sentence, pause, repeat');
  }

  void _onPcm(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      _pending.add(data.getInt16(i, Endian.little) / 32768.0);
    }
    while (_pending.length >= _window) {
      _vad!.acceptWaveform(Float32List.fromList(_pending.sublist(0, _window)));
      _pending.removeRange(0, _window);
      final speech = _vad!.isDetected();
      if (speech != _speech) setState(() => _speech = speech);
      while (!_vad!.isEmpty()) {
        _queue.add(_vad!.front().samples);
        _vad!.pop();
      }
    }
    _drain();
  }

  Future<void> _drain() async {
    if (_busy || _queue.isEmpty) return;
    _busy = true;
    while (_queue.isNotEmpty) {
      final audio = _queue.removeAt(0);
      final n = ++_utterance;
      final secs = (audio.length / 16000).toStringAsFixed(2);
      await _saveWav(audio, n);
      for (final e in _engines.entries) {
        for (final limit in [false, true]) {
          final r = await _decode(e.value, audio, limit);
          _say(
            '#$n ${secs}s ${e.key} ${limit ? 'win' : 'full'} '
            '${r.$2}ms conf=${r.$3.toStringAsFixed(2)} rss=${_rssMb}MB | ${r.$1}',
          );
        }
      }
    }
    _busy = false;
  }

  Future<(String, int, double)> _decode(
    WhisperCppEngine engine,
    Float32List audio,
    bool limit,
  ) {
    final address = engine.address;
    final threads = engine.threads;
    return Isolate.run(() {
      final e = WhisperCppEngine.fromAddress(
        address,
        threads: threads,
        limitAudioWindow: limit,
      );
      final r = e.decodeSync(audio);
      return (r.text, e.lastDecodeMs, r.avgLogProb);
    });
  }

  Future<void> _saveWav(Float32List audio, int n) async {
    final dir = Directory(
      '${(await getExternalStorageDirectory())!.path}/recordings',
    );
    await dir.create(recursive: true);
    final pcm = ByteData(audio.length * 2);
    for (var i = 0; i < audio.length; i++) {
      pcm.setInt16(
        i * 2,
        (audio[i].clamp(-1.0, 1.0) * 32767).round(),
        Endian.little,
      );
    }
    final header = ByteData(44)
      ..setUint32(0, 0x46464952, Endian.little)
      ..setUint32(4, 36 + pcm.lengthInBytes, Endian.little)
      ..setUint32(8, 0x45564157, Endian.little)
      ..setUint32(12, 0x20746d66, Endian.little)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, 16000, Endian.little)
      ..setUint32(28, 32000, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x61746164, Endian.little)
      ..setUint32(40, pcm.lengthInBytes, Endian.little);
    await File('${dir.path}/utt_$n.wav').writeAsBytes([
      ...header.buffer.asUint8List(),
      ...pcm.buffer.asUint8List(),
    ]);
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    await _recorder.stop();
    _say('stopped');
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    _vad?.free();
    for (final e in _engines.values) {
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 8,
              color: _speech ? Colors.white : Colors.grey.shade900,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final l in _log)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        l,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ElevatedButton(onPressed: _start, child: const Text('Start')),
                  const SizedBox(width: 16),
                  ElevatedButton(onPressed: _stop, child: const Text('Stop')),
                  const SizedBox(width: 16),
                  Text(
                    _busy ? 'decoding...' : '',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
