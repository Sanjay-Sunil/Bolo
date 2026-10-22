import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_clock.dart';
import '../app/model_manager.dart';
import '../conversation/chat_entry.dart';
import '../conversation/conversation_controller.dart';
import '../conversation/conversation_phase.dart';
import '../conversation/conversation_provider.dart';
import '../conversation/spoken_phrase.dart';
import 'frequency_bars.dart';
import 'key_sheet.dart';
import 'palette.dart';
import 'reply_text.dart';

/// One full-screen stage (bars, live words, reply); scrolling down reveals
/// the conversation history.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(conversationProvider);
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Palette.background,
        body: LayoutBuilder(
          builder: (context, box) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: box.maxHeight,
                  child: SafeArea(child: _Stage(controller: c)),
                ),
              ),
              _History(controller: c),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.controller});

  final ConversationController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 18),
          Row(
            children: [
              // Long-press the name to change the Groq key.
              GestureDetector(
                onLongPress: () => openKeySheet(context, c),
                child: Text(
                  'bolo',
                  style: inter(
                    15,
                    weight: 600,
                    color: Palette.textSoft,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const Spacer(),
              ValueListenableBuilder(
                valueListenable: c.phase,
                builder: (context, phase, _) => Text(
                  _phaseLabel(phase),
                  style: inter(12, color: Palette.textMuted, letterSpacing: 1),
                ),
              ),
            ],
          ),
          const Spacer(flex: 3),
          GestureDetector(
            onTap: () => talkOrAskForKey(context, c),
            child: FrequencyBars(controller: c),
          ),
          const SizedBox(height: 44),
          SizedBox(height: 220, child: _CenterText(controller: c)),
          const Spacer(flex: 2),
          ValueListenableBuilder(
            valueListenable: c.status,
            builder: (context, status, _) => status.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      status,
                      textAlign: TextAlign.center,
                      style: inter(13, color: Palette.danger),
                    ),
                  ),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([c.metrics, c.accuracy]),
            builder: (context, _) => Column(
              children: [
                for (final line in [c.metrics.value, c.accuracy.value])
                  if (line.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        line,
                        textAlign: TextAlign.center,
                        style: inter(11, color: Palette.textMuted),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Controls(controller: c),
          const SizedBox(height: 14),
          ValueListenableBuilder(
            valueListenable: c.history,
            builder: (context, h, _) => AnimatedOpacity(
              opacity: h.isEmpty ? 0 : 1,
              duration: const Duration(milliseconds: 400),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Palette.textMuted,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _phaseLabel(ConversationPhase p) => switch (p) {
    ConversationPhase.loading => 'LOADING',
    ConversationPhase.idle => '',
    ConversationPhase.listening => 'LISTENING',
    ConversationPhase.thinking => 'THINKING',
    ConversationPhase.speaking => 'SPEAKING',
    ConversationPhase.failed => 'ERROR',
  };
}

class _CenterText extends StatelessWidget {
  const _CenterText({required this.controller});

  final ConversationController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListenableBuilder(
      listenable: Listenable.merge([
        c.phase,
        c.userText,
        c.reply,
        c.downloadProgress,
        c.needsKey,
      ]),
      builder: (context, _) {
        final phase = c.phase.value;
        final user = c.userText.value;
        final reply = c.reply.value;
        final Widget child;
        switch (phase) {
          case ConversationPhase.loading:
            final p = c.downloadProgress.value;
            child = p == null ? _hint('Getting ready…') : _download(p);
          case ConversationPhase.failed:
            child = _hint('Couldn\'t start');
          case ConversationPhase.idle:
            child = c.needsKey.value
                ? _hint('Add your Groq key to start\nTap the mic')
                : reply.isNotEmpty
                ? _replyBlock(user, reply, dim: true)
                : _hint('Tap the bars and talk\nEnglish or Hinglish');
          case ConversationPhase.listening:
            if (user.isNotEmpty) {
              child = _userWords(user, live: true);
            } else if (reply.isNotEmpty) {
              child = _replyBlock(user, reply, dim: true);
            } else {
              child = _hint('Listening…');
            }
          case ConversationPhase.thinking:
            child = user.isEmpty
                ? const SizedBox.shrink()
                : _userWords(user, live: true);
          case ConversationPhase.speaking:
            child = _replyBlock(user, reply, dim: false);
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          child: Align(alignment: Alignment.topCenter, child: child),
        );
      },
    );
  }

  Widget _download(double p) => Column(
    key: const ValueKey('download'),
    mainAxisSize: MainAxisSize.min,
    children: [
      _hint('Downloading the voice and speech models\nfirst launch only'),
      const SizedBox(height: 14),
      Text(
        '${(p * 100).round()}%  ·  '
        '${(p * ModelManager.totalBytes / 1e6).round()} of '
        '${(ModelManager.totalBytes / 1e6).round()} MB',
        style: inter(12, color: Palette.textMuted),
      ),
    ],
  );

  Widget _hint(String text) => Text(
    text,
    key: ValueKey(text),
    textAlign: TextAlign.center,
    style: inter(17, weight: 350, color: Palette.textMuted, height: 1.6),
  );

  Widget _userWords(String text, {required bool live}) {
    // Same look while listening and while thinking, so nothing jumps when
    // the turn ends.
    final words = Text(
      text,
      textAlign: TextAlign.center,
      style: inter(16, color: Palette.textSoft, height: 1.45),
    );
    return live
        ? _FollowLatest(key: const ValueKey('user'), child: words)
        : words;
  }

  Widget _replyBlock(
    String user,
    List<SpokenPhrase> reply, {
    required bool dim,
  }) => _FollowLatest(
    key: ValueKey('reply-${reply.isEmpty ? 0 : reply.first.start}'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (user.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              user,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: inter(14, color: Palette.textMuted),
            ),
          ),
        ReplyText(phrases: reply, dim: dim && reply.last.end < now),
      ],
    ),
  );
}

/// Keeps the newest lines in view: once the text outgrows the area, earlier
/// lines slide up and fade out at the top edge.
class _FollowLatest extends StatelessWidget {
  const _FollowLatest({super.key, required this.child});

  static const _fade = 28.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0x00000000), Color(0xFF000000)],
          stops: [0, _fade / rect.height],
        ).createShader(rect),
        child: SingleChildScrollView(
          reverse: true,
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: _fade),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final ConversationController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ValueListenableBuilder(
      valueListenable: c.phase,
      builder: (context, phase, _) {
        final running =
            phase == ConversationPhase.listening ||
            phase == ConversationPhase.thinking ||
            phase == ConversationPhase.speaking;
        final ready = phase == ConversationPhase.idle || running;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundButton(
              icon: Icons.keyboard_rounded,
              size: 46,
              onTap:
                  phase == ConversationPhase.idle ||
                      phase == ConversationPhase.listening
                  ? () => _openKeyboard(context)
                  : null,
            ),
            const SizedBox(width: 28),
            _RoundButton(
              icon: running ? Icons.stop_rounded : Icons.mic_rounded,
              size: 68,
              filled: true,
              onTap: ready ? () => talkOrAskForKey(context, c) : null,
            ),
            const SizedBox(width: 28 + 46),
          ],
        );
      },
    );
  }

  Future<void> _openKeyboard(BuildContext context) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => const _TypeSheet(),
    );
    if (text != null) await controller.sendTyped(text);
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled && enabled ? Palette.text : Colors.transparent,
          border: Border.all(
            color: enabled ? Palette.hairline : Palette.surface,
            width: 1.2,
          ),
        ),
        child: Icon(
          icon,
          size: size * 0.42,
          color: filled
              ? (enabled ? Palette.background : Palette.textMuted)
              : (enabled ? Palette.textSoft : Palette.hairline),
        ),
      ),
    );
  }
}

class _TypeSheet extends StatefulWidget {
  const _TypeSheet();

  @override
  State<_TypeSheet> createState() => _TypeSheetState();
}

class _TypeSheetState extends State<_TypeSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() => Navigator.pop(context, _text.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        12,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              autofocus: true,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              cursorColor: Palette.text,
              style: inter(16),
              decoration: InputDecoration(
                hintText: 'Type in English or Hinglish',
                hintStyle: inter(16, color: Palette.textMuted),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: _send,
            icon: const Icon(Icons.arrow_upward_rounded),
            color: Palette.text,
          ),
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.controller});

  final ConversationController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.history,
      builder: (context, entries, _) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 48),
        sliver: SliverList.list(
          children: [
            if (entries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  'CONVERSATION',
                  style: inter(
                    11,
                    weight: 600,
                    color: Palette.textMuted,
                    letterSpacing: 2,
                  ),
                ),
              ),
            for (final e in entries.reversed) _HistoryItem(entry: e),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.entry});

  final ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final conf = [
      if (e.accuracy.isNotEmpty) e.accuracy,
      if (e.confidence != null) 'STT conf ${(e.confidence! * 100).round()}%',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.typed ? '⌨  ${e.user}' : e.user,
            style: inter(14, color: Palette.textSoft),
          ),
          const SizedBox(height: 8),
          Text(e.reply, style: inter(16, weight: 380)),
          for (final line in [e.metrics, conf])
            if (line.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(line, style: inter(11, color: Palette.textMuted)),
              ),
        ],
      ),
    );
  }
}
