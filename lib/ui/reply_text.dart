import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/app_clock.dart';
import '../conversation/spoken_phrase.dart';
import 'palette.dart';

/// Reply text revealed word by word as its audio plays.
class ReplyText extends StatefulWidget {
  const ReplyText({super.key, required this.phrases, this.dim = false});

  final List<SpokenPhrase> phrases;

  /// Show everything, muted (the reply after it has finished).
  final bool dim;

  @override
  State<ReplyText> createState() => _ReplyTextState();
}

class _ReplyTextState extends State<ReplyText>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final last = widget.phrases.isEmpty ? null : widget.phrases.last;
      if (widget.dim || last == null || now > last.end) return;
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = now;
    final style = inter(
      24,
      weight: 350,
      color: widget.dim ? Palette.textSoft : Palette.text,
      height: 1.4,
    );
    final spans = <TextSpan>[];
    for (final p in widget.phrases) {
      final words = p.text.split(' ');
      final total = p.text.length;
      final progress = widget.dim ? 1.0 : p.progressAt(t);
      var chars = 0;
      for (final w in words) {
        // A word shows once speech reaches its middle, fading in over it.
        final from = chars / total, to = (chars + w.length) / total;
        chars += w.length + 1;
        final reveal = ((progress - from) / (to - from + 1e-6) * 1.6).clamp(
          0.0,
          1.0,
        );
        if (reveal == 0) break;
        spans.add(
          TextSpan(
            text: '$w ',
            style: style.copyWith(
              color: style.color!.withValues(alpha: reveal),
            ),
          ),
        );
      }
    }
    return Text.rich(TextSpan(children: spans), textAlign: TextAlign.center);
  }
}
