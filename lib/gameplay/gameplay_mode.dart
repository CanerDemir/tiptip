import 'package:flutter/material.dart';

enum GameplayMode { water, star, jelly }

extension GameplayModeVisual on GameplayMode {
  IconData get icon {
    switch (this) {
      case GameplayMode.water:
        return Icons.water_drop_rounded;
      case GameplayMode.star:
        return Icons.star_rounded;
      case GameplayMode.jelly:
        return Icons.bubble_chart_rounded;
    }
  }

  Color get accent {
    switch (this) {
      case GameplayMode.water:
        return const Color(0xFF0284C7);
      case GameplayMode.star:
        return const Color(0xFFEAB308);
      case GameplayMode.jelly:
        return const Color(0xFFEC4899);
    }
  }

  String get semanticLabel {
    switch (this) {
      case GameplayMode.water:
        return 'Water mode';
      case GameplayMode.star:
        return 'Star mode';
      case GameplayMode.jelly:
        return 'Jelly wobble mode';
    }
  }
}
