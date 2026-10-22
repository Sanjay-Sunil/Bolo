import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads [url] into app storage once and returns the local path.
Future<String> ensureModel(String url, String fileName) async {
  final dir = Directory(
    '${(await getApplicationSupportDirectory()).path}/models',
  );
  await dir.create(recursive: true);
  final file = File('${dir.path}/$fileName');
  if (await file.exists() && await file.length() > 0) return file.path;
  final response = await http.Client().send(
    http.Request('GET', Uri.parse(url)),
  );
  if (response.statusCode != 200) {
    throw HttpException('Download failed (${response.statusCode}): $url');
  }
  final tmp = File('${file.path}.part');
  await response.stream.pipe(tmp.openWrite());
  await tmp.rename(file.path);
  return file.path;
}
