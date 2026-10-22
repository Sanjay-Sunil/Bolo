import 'package:flutter/painting.dart';

/// Black, near-white type, and two soft accent gradients: one for the
/// user's voice, one for the assistant's.
abstract final class Palette {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF0D0D0F);
  static const hairline = Color(0xFF1C1C20);
  static const text = Color(0xFFF4F4F5);
  static const textSoft = Color(0xFFA1A1AA);
  static const textMuted = Color(0xFF5A5A63);
  static const danger = Color(0xFFFCA5A5);

  static const userVoice = [Color(0xFF6EE7B7), Color(0xFF22D3EE)];
  static const agentVoice = [Color(0xFFFDBA74), Color(0xFFF472B6)];
  static const idle = [Color(0xFF3F3F46), Color(0xFF71717A)];
}

/// Inter at a given weight (the bundled font is variable).
TextStyle inter(
  double size, {
  double weight = 400,
  Color color = Palette.text,
  double height = 1.35,
  double letterSpacing = 0,
}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
  fontVariations: [FontVariation('wght', weight)],
  fontFeatures: const [FontFeature.tabularFigures()],
);
