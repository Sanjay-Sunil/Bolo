import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/home_page.dart';
import 'ui/palette.dart';

void main() {
  runApp(const ProviderScope(child: BoloApp()));
}

class BoloApp extends StatelessWidget {
  const BoloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bolo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.background,
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          surface: Palette.background,
          primary: Palette.text,
        ),
      ),
      home: const HomePage(),
    );
  }
}
