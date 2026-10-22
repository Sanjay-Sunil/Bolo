// Gate G3: Kokoro Hindi (int8 vs fp32) vs Piper hi_IN on the phone.
// Packs are served from the laptop: `adb reverse tcp:8765 tcp:8765` + `python -m http.server 8765` in models/.
// Run: flutter run --release -t lib/spike/g3_tts.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import '../app/thread_budget.dart';
import 'spike_models.dart';

void main() => runApp(const MaterialApp(home: G3Page()));

const _laptop = 'http://127.0.0.1:8765';
const _hindiVoice = 31; // hf_alpha
const _englishVoice = 3; // af_heart

const _phrases = [
  ('hi-mix01', 'हाँ, आपका फ़्लाइट टिकट कन्फ़र्म हो गया है।'),
  ('hi-mix02', 'कल बैंगलोर में मौसम क्लाउडी रहेगा, अट्ठाईस डिग्री के आसपास।'),
  ('hi-mix03', 'आपकी नेक्स्ट मीटिंग दोपहर तीन बजे डिज़ाइन टीम के साथ है।'),
  ('hi-mix04', 'ठीक है, मैं आपको पाँच बजे रिमाइंडर भेज दूँगी।'),
  (
    'hi-mix05',
    'ट्रैफ़िक बहुत ज़्यादा है, ऑफ़िस पहुँचने में चालीस मिनट लगेंगे।',
  ),
  ('hi-mix06', 'आपके फ़ोन की बैटरी बीस परसेंट पर है, चार्जर लगा लीजिए।'),
  ('hi-mix07', 'सॉरी, मैं ईमेल नहीं भेज सकती, पर आप ड्राफ़्ट तैयार रखिए।'),
  ('hi-mix08', 'वीकेंड पर मूवी देखने का प्लान अच्छा आइडिया है।'),
  ('hi-mix09', 'आज का शेड्यूल थोड़ा बिज़ी है, लंच के बाद दो कॉल्स हैं।'),
  ('hi-mix10', 'ओके, सुबह सात बजे का अलार्म याद रखिए।'),
  ('hi-latin1', 'आपकी next meeting दोपहर तीन बजे design team के साथ है।'),
  ('hi-latin2', 'आपके phone की battery बीस percent पर है, charger लगा लीजिए।'),
  ('hi-latin3', 'आज का schedule थोड़ा busy है, lunch के बाद दो calls हैं।'),
  ('en-first', 'Sure, your'),
  ('en', 'Sure, your meeting is at 5 PM.'),
];

const _englishPiper = ['lessac', 'amy', 'hfc_female'];

class G3Page extends StatefulWidget {
  const G3Page({super.key});

  @override
  State<G3Page> createState() => _G3PageState();
}

class _G3PageState extends State<G3Page> {
  final _log = <String>[];
  final _clips = <String, so.GeneratedAudio>{};
  final int _threads = inferenceThreads();
  bool _busy = false;
  bool _playing = false;

  void _say(String line) {
    debugPrint('G3 $line');
    setState(() {
      _log.insert(0, line);
      if (_log.length > 60) _log.removeLast();
    });
  }

  int get _rssMb => ProcessInfo.currentRss ~/ (1024 * 1024);

  Future<String> _pack(String name) async {
    final root = (await getApplicationSupportDirectory()).path;
    final dir = Directory('$root/models/$name');
    if (await File('${dir.path}/tokens.txt').exists()) return dir.path;
    _say('downloading $name.tar ...');
    final tar = await ensureModel('$_laptop/$name.tar', '$name.tar');
    await extractFileToDisk(tar, dir.path);
    await File(tar).delete();
    return dir.path;
  }

  Future<so.OfflineTtsModelConfig> _config(String engine) async {
    if (engine.startsWith('piper')) {
      final p = await _pack(engine);
      return so.OfflineTtsModelConfig(
        vits: so.OfflineTtsVitsModelConfig(
          model: engine == 'piper-hi'
              ? '$p/hi_IN-priyamvada-medium.onnx'
              : '$p/model.onnx',
          tokens: '$p/tokens.txt',
          dataDir: '$p/espeak-ng-data',
        ),
        numThreads: _threads,
        debug: false,
      );
    }
    final k = await _pack('kokoro-int8');
    final model = engine == 'kokoro-fp32'
        ? await ensureModel('$_laptop/kokoro-fp32.onnx', 'kokoro-fp32.onnx')
        : '$k/model.int8.onnx';
    return so.OfflineTtsModelConfig(
      kokoro: so.OfflineTtsKokoroModelConfig(
        model: model,
        voices: '$k/voices.bin',
        tokens: '$k/tokens.txt',
        dataDir: '$k/espeak-ng-data',
        lexicon: '$k/lexicon-us-en.txt',
      ),
      numThreads: _threads,
      debug: false,
    );
  }

  Future<void> _run(String engine) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      so.initBindings();
      final config = await _config(engine);
      _clips.clear();
      final before = _rssMb;
      final sw = Stopwatch()..start();
      final tts = so.OfflineTts(so.OfflineTtsConfig(model: config));
      _say(
        '$engine loaded in ${sw.elapsedMilliseconds} ms, '
        'rss +${_rssMb - before}MB (now ${_rssMb}MB) threads=$_threads',
      );
      // Let the log paint before the blocking synth calls.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      for (final (name, text) in _phrases) {
        final english = name.startsWith('en');
        if (english && engine == 'piper-hi') continue;
        if (!english && engine.startsWith('piper-en')) continue;
        final sid = engine.startsWith('piper')
            ? 0
            : (english ? _englishVoice : _hindiVoice);
        for (var run = 1; run <= 3; run++) {
          sw.reset();
          final audio = tts.generate(text: text, sid: sid);
          final ms = sw.elapsedMilliseconds;
          final secs = audio.samples.length / audio.sampleRate;
          _say(
            '$engine $name run$run ${ms}ms audio=${secs.toStringAsFixed(2)}s '
            'rtf=${(ms / 1000 / secs).toStringAsFixed(2)} rss=${_rssMb}MB',
          );
          _clips['$engine $name'] = audio;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }
      tts.free();
      _say('$engine done');
    } catch (e) {
      _say('$engine error: $e');
    }
    setState(() => _busy = false);
  }

  Future<void> _play() async {
    if (_playing) return;
    setState(() => _playing = true);
    for (final e in _clips.entries.toList()) {
      if (!_playing) break;
      final a = e.value;
      _say('playing ${e.key}');
      await FlutterPcmSound.release();
      await FlutterPcmSound.setup(sampleRate: a.sampleRate, channelCount: 1);
      final pcm = ByteData(a.samples.length * 2);
      for (var i = 0; i < a.samples.length; i++) {
        pcm.setInt16(
          i * 2,
          (a.samples[i].clamp(-1.0, 1.0) * 32767).round(),
          Endian.little,
        );
      }
      await FlutterPcmSound.feed(PcmArrayInt16(bytes: pcm));
      final ms = a.samples.length * 1000 ~/ a.sampleRate;
      await Future<void>.delayed(Duration(milliseconds: ms + 600));
    }
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _stopPlayback() async {
    _playing = false;
    await FlutterPcmSound.release();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget button(String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ElevatedButton(
        onPressed: _busy || _playing ? null : onTap,
        child: Text(label),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
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
              child: Wrap(
                children: [
                  button('Kokoro int8', () => _run('kokoro-int8')),
                  button('Kokoro fp32', () => _run('kokoro-fp32')),
                  button('Piper hi', () => _run('piper-hi')),
                  for (final v in _englishPiper)
                    button('Piper $v', () => _run('piper-en-$v')),
                  button('Play', _play),
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: ElevatedButton(
                      onPressed: _playing ? _stopPlayback : null,
                      child: const Text('Stop'),
                    ),
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
