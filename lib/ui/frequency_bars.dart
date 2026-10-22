import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/app_clock.dart';
import '../conversation/conversation_controller.dart';
import '../conversation/conversation_phase.dart';
import 'palette.dart';

/// Seven rounded bars driven by voice frequency bands: the mic while
/// listening, the reply audio while speaking, a slow wave while thinking.
class FrequencyBars extends StatefulWidget {
  const FrequencyBars({super.key, required this.controller});

  final ConversationController controller;

  @override
  State<FrequencyBars> createState() => _FrequencyBarsState();
}

class _FrequencyBarsState extends State<FrequencyBars>
    with SingleTickerProviderStateMixin {
  static const _bands = 7;

  /// Loudest (lowest) band in the middle, higher bands towards the edges.
  static const _order = [5, 3, 1, 0, 2, 4, 6];

  late final Ticker _ticker;
  final _levels = List<double>.filled(_bands, 0);
  final _repaint = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration _) {
    final c = widget.controller;
    final t = now;
    final secs = t.inMicroseconds / 1e6;
    final target = List<double>.filled(_bands, 0);
    switch (c.phase.value) {
      case ConversationPhase.listening:
        final mic = c.micLevels;
        for (var i = 0; i < _bands && i < mic.length; i++) {
          target[i] = mic[i];
        }
      case ConversationPhase.speaking:
        Float32List? playing;
        for (final p in c.reply.value) {
          playing = p.levelsAt(t, _bands);
          if (playing != null) break;
        }
        if (playing != null) {
          for (var i = 0; i < _bands; i++) {
            target[i] = playing[i];
          }
        }
      case ConversationPhase.thinking:
        for (var i = 0; i < _bands; i++) {
          target[i] = 0.18 + 0.14 * math.sin(secs * 5 - _order.indexOf(i));
        }
      default:
        for (var i = 0; i < _bands; i++) {
          target[i] = 0.05 + 0.03 * math.sin(secs * 1.6 + i * 0.6);
        }
    }
    for (var i = 0; i < _bands; i++) {
      final rate = target[i] > _levels[i] ? 0.55 : 0.14;
      _levels[i] += (target[i] - _levels[i]) * rate;
    }
    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller.phase,
      builder: (context, phase, _) {
        final colors = switch (phase) {
          ConversationPhase.listening => Palette.userVoice,
          ConversationPhase.speaking ||
          ConversationPhase.thinking => Palette.agentVoice,
          _ => Palette.idle,
        };
        return CustomPaint(
          size: const Size(176, 112),
          painter: _BarsPainter(
            levels: _levels,
            order: _order,
            colors: colors,
            repaint: _repaint,
          ),
        );
      },
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.levels,
    required this.order,
    required this.colors,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<double> levels;
  final List<int> order;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 12.0;
    final gap = (size.width - barWidth * order.length) / (order.length - 1);
    final shader = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: colors,
    ).createShader(Offset.zero & size);
    final paint = Paint()..shader = shader;
    for (var i = 0; i < order.length; i++) {
      final level = levels[order[i]].clamp(0.0, 1.0);
      final h = barWidth + (size.height - barWidth) * level;
      final x = i * (barWidth + gap);
      final rect = Rect.fromCenter(
        center: Offset(x + barWidth / 2, size.height / 2),
        width: barWidth,
        height: h,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.colors != colors;
}
