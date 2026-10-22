/// One file the app downloads on first launch.
class ModelAsset {
  const ModelAsset({
    required this.url,
    required this.sha256,
    required this.bytes,
    this.unpacksTo,
  });

  final String url;
  final String sha256;
  final int bytes;

  /// For a `.tar.bz2`, the directory it unpacks to; null for a plain file.
  final String? unpacksTo;

  String get fileName => Uri.parse(url).pathSegments.last;
}
