import 'dart:typed_data';

import 'stt_result.dart';

abstract interface class SttEngine {
  Future<SttResult> decode(Float32List audio, {String? prompt});
}
