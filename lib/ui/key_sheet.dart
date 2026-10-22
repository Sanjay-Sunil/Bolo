import 'package:flutter/material.dart';

import '../conversation/conversation_controller.dart';
import 'palette.dart';

/// Asks for the user's own Groq key, checks it, and saves it on the phone.
Future<void> openKeySheet(
  BuildContext context,
  ConversationController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Palette.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
  ),
  builder: (context) => _KeySheet(controller: controller),
);

/// Mic or bars tapped: ask for a key first if there is none.
void talkOrAskForKey(BuildContext context, ConversationController c) {
  if (c.needsKey.value) {
    openKeySheet(context, c);
  } else {
    c.toggle();
  }
}

class _KeySheet extends StatefulWidget {
  const _KeySheet({required this.controller});

  final ConversationController controller;

  @override
  State<_KeySheet> createState() => _KeySheetState();
}

class _KeySheetState extends State<_KeySheet> {
  final _text = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final error = await widget.controller.setApiKey(_text.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _checking = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        22,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Groq API key', style: inter(17, weight: 550)),
          const SizedBox(height: 6),
          Text(
            'Replies come from Groq. Get a free key at console.groq.com. '
            'It is checked once and kept only on this phone.',
            style: inter(13, color: Palette.textSoft, height: 1.45),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _text,
            autofocus: true,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            cursorColor: Palette.text,
            style: inter(15),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: 'gsk_…',
              hintStyle: inter(15, color: Palette.textMuted),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Palette.hairline),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Palette.textSoft),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: inter(13, color: Palette.danger)),
          ],
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _checking ? null : _save,
              child: Text(
                _checking ? 'Checking…' : 'Save',
                style: inter(15, weight: 550, color: Palette.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
