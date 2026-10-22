import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/app_clock.dart';
import '../conversation/conversation_controller.dart';
import '../conversation/conversation_phase.dart';
import 'palette.dart';

/// Seven rounded bars driven by voice frequency bands: the mic while
/// listening, the reply audio while speaking. While thinking or loading, a
/// soft peak of light sweeps across them instead of a separate spinner.
class FrequencyBars extends StatefulWidget {
  const FrequencyBars({super.key, required this.controller});

  final ConversationController controller;

  @override
  State<FrequencyBars> createState() => _FrequencyBarsState();
}

class _FrequencyBarsState extends State<FrequencyBars>
    with SingleTickerProviderStateMixin {
  static const _bars = 7;

  /// Band shown by each bar: the loudest (lowest) band in the middle,
  /// higher bands towards the edges.
  static const _bandOf = [5, 3, 1, 0, 2, 4, 6];

  late final Ticker _ticker;
  final _levels = List<double>.filled(_bars, 0);
  final _glow = List<double>.filled(_bars, 1);
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
    final level = List<double>.filled(_bars, 0);
    final glow = List<double>.filled(_bars, 1);

    void fromBands(Float32List bands) {
      for (var i = 0; i < _bars; i++) {
        final b = _bandOf[i];
        level[i] = b < bands.length ? bands[b] : 0;
      }
    }

    void sweep({required double period, required double height}) {
      // A Gaussian peak travelling left to right, slightly past both edges.
      final x = (secs % period) / period * 1.6 - 0.3;
      for (var i = 0; i < _bars; i++) {
        final d = i / (_bars - 1) - x;
        final peak = math.exp(-d * d / (2 * 0.13 * 0.13));
        level[i] = 0.1 + height * peak;
        glow[i] = 0.3 + 0.7 * peak;
      }
    }

    switch (c.phase.value) {
      case ConversationPhase.listening:
        fromBands(c.micLevels);
      case ConversationPhase.speaking:
        for (final p in c.reply.value) {
          final playing = p.levelsAt(t, _bands);
          if (playing != null) {
            fromBands(playing);
            break;
          }
        }
      case ConversationPhase.thinking:
        sweep(period: 1.1, height: 0.55);
      case ConversationPhase.loading:
        sweep(period: 1.8, height: 0.4);
      case ConversationPhase.idle || ConversationPhase.failed:
        for (var i = 0; i < _bars; i++) {
          level[i] = 0.05 + 0.03 * math.sin(secs * 1.6 + i * 0.6);
        }
    }
    for (var i = 0; i < _bars; i++) {
      final rate = level[i] > _levels[i] ? 0.5 : 0.16;
      _levels[i] += (level[i] - _levels[i]) * rate;
      _glow[i] += (glow[i] - _glow[i]) * 0.3;
    }
    _repaint.value++;
  }

  static const _bands = 7;

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
          ConversationPhase.listening ||
          ConversationPhase.loading => Palette.userVoice,
          ConversationPhase.speaking ||
          ConversationPhase.thinking => Palette.agentVoice,
          _ => Palette.idle,
        };
        return CustomPaint(
          size: const Size(132, 112),
          painter: _BarsPainter(
            levels: _levels,
            glow: _glow,
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
    required this.glow,
    required this.colors,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<double> levels;
  final List<double> glow;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 6.0;
    final n = levels.length;
    final gap = (size.width - barWidth * n) / (n - 1);
    final shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: colors,
    ).createShader(Offset.zero & size);
    for (var i = 0; i < n; i++) {
      final level = levels[i].clamp(0.0, 1.0);
      final h = barWidth + (size.height - barWidth) * level;
      final x = i * (barWidth + gap);
      final rect = Rect.fromCenter(
        center: Offset(x + barWidth / 2, size.height / 2),
        width: barWidth,
        height: h,
      );
      final paint = Paint()
        ..shader = shader
        ..color = Color.fromRGBO(0, 0, 0, glow[i].clamp(0.0, 1.0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.colors != colors;
}
