import 'package:flutter/material.dart';

import 'screens/gameplay_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/theme.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: TiptipTheme.light,
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (BuildContext context) {
          return OnboardingScreen(
            onStartPlaying: (mode) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => GameplayScreen(initialMode: mode),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
