import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Development-only model source until `ModelManager` exists: files are pulled
/// once from the laptop (`python -m http.server 8765` in models/ +
/// `adb reverse tcp:8765 tcp:8765`) and cached in app support storage.
class DevModelStore {
  DevModelStore._(this._dir);

  static const _laptop = 'http://127.0.0.1:8765';

  final String _dir;

  static Future<DevModelStore> open() async {
    final dir = '${(await getApplicationSupportDirectory()).path}/models';
    await Directory(dir).create(recursive: true);
    return DevModelStore._(dir);
  }

  /// Path of [name], downloading it first if needed.
  Future<String> file(String name) async {
    final file = File('$_dir/$name');
    if (await file.exists() && await file.length() > 0) return file.path;
    final response = await http.Client().send(
      http.Request('GET', Uri.parse('$_laptop/$name')),
    );
    if (response.statusCode != 200) {
      throw HttpException('Download failed (${response.statusCode}): $name');
    }
    final tmp = File('${file.path}.part');
    await response.stream.pipe(tmp.openWrite());
    await tmp.rename(file.path);
    return file.path;
  }

  /// Directory of the unpacked `<name>.tar`, downloading it first if needed.
  Future<String> pack(String name) async {
    final dir = Directory('$_dir/$name');
    if (await File('${dir.path}/tokens.txt').exists()) return dir.path;
    final tar = await file('$name.tar');
    await extractFileToDisk(tar, dir.path);
    await File(tar).delete();
    return dir.path;
  }
}
