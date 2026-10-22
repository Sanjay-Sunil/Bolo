import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'model_asset.dart';
import 'model_paths.dart';

/// Downloads the on-device models once (the only network use besides the
/// LLM), checks their SHA-256 and unpacks the voice packs. Offline after.
class ModelManager {
  ModelManager({http.Client? client}) : _client = client ?? http.Client();

  /// Development mirror (e.g. the laptop over `adb reverse`) serving the same
  /// file names: `--dart-define=BOLO_MODEL_MIRROR=http://127.0.0.1:8765`.
  static const _mirror = String.fromEnvironment('BOLO_MODEL_MIRROR');

  static const _sherpa =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download';

  static const assets = [
    ModelAsset(
      url: '$_sherpa/asr-models/silero_vad_v5.onnx',
      sha256:
          '6b99cbfd39246b6706f98ec13c7c50c6b299181f2474fa05cbc8046acc274396',
      bytes: 2313101,
    ),
    ModelAsset(
      url: 'https://github.com/Sanjay-Sunil/Bolo/releases/download/models-v1/ggml-swift-q8_0.bin',
      sha256:
          '8550803dc10fa9f0b3db5cb884f8580c61067b062a67ee169d5789bcd0faec90',
      bytes: 81768585,
    ),
    ModelAsset(
      url:
          '$_sherpa/tts-models/vits-piper-hi_IN-priyamvada-medium-int8.tar.bz2',
      sha256:
          '2997c7bbc211e524af83dfdffe7712942f10bd76c079a526af2e09d1f36a92f2',
      bytes: 21097319,
      unpacksTo: 'vits-piper-hi_IN-priyamvada-medium-int8',
    ),
    ModelAsset(
      url: '$_sherpa/tts-models/vits-piper-en_US-lessac-medium-int8.tar.bz2',
      sha256:
          'f1c6d0295cf16087b05f80fdca5b44daca5cd78e2c425d419a42ba34929805f9',
      bytes: 20969179,
      unpacksTo: 'vits-piper-en_US-lessac-medium-int8',
    ),
  ];

  static int get totalBytes => assets.fold(0, (sum, a) => sum + a.bytes);

  final http.Client _client;

  /// 0..1 while downloading; null when nothing needs downloading.
  final progress = ValueNotifier<double?>(null);

  /// Makes sure every model is on disk and returns their paths.
  Future<ModelPaths> ensure() async {
    final root = '${(await getApplicationSupportDirectory()).path}/models-v1';
    await Directory(root).create(recursive: true);
    final missing = [
      for (final a in assets)
        if (!await File('$root/${a.fileName}.ok').exists()) a,
    ];
    if (missing.isEmpty) return ModelPaths(root);

    final total = missing.fold(0, (sum, a) => sum + a.bytes);
    var done = 0;
    progress.value = 0;
    try {
      for (final a in missing) {
        await _download(a, root, (n) {
          progress.value = (done + n) / total;
        });
        done += a.bytes;
        if (a.unpacksTo != null) {
          await _unpack('$root/${a.fileName}', root);
          await File('$root/${a.fileName}').delete();
        }
        await File('$root/${a.fileName}.ok').writeAsString(a.sha256);
      }
    } finally {
      progress.value = null;
    }
    return ModelPaths(root);
  }

  Future<void> _download(
    ModelAsset a,
    String root,
    void Function(int received) onBytes,
  ) async {
    final url = _mirror.isEmpty ? a.url : '$_mirror/${a.fileName}';
    final response = await _client.send(http.Request('GET', Uri.parse(url)));
    if (response.statusCode != 200) {
      throw HttpException('Download failed (${response.statusCode}): $url');
    }
    final part = File('$root/${a.fileName}.part');
    final sink = part.openWrite();
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    var received = 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      hasher.add(chunk);
      received += chunk.length;
      onBytes(received);
    }
    await sink.close();
    hasher.close();
    if (digest.value.toString() != a.sha256) {
      await part.delete();
      throw StateError('Checksum mismatch for ${a.fileName}');
    }
    await part.rename('$root/${a.fileName}');
  }

  static Future<void> _unpack(String archive, String root) =>
      Isolate.run(() => extractFileToDisk(archive, root));

  void dispose() => _client.close();
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
