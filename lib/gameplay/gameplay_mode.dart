import 'package:flutter/material.dart';

enum GameplayMode { water, star, geometric }

extension GameplayModeVisual on GameplayMode {
  IconData get icon {
    switch (this) {
      case GameplayMode.water:
        return Icons.water_drop_rounded;
      case GameplayMode.star:
        return Icons.star_rounded;
      case GameplayMode.geometric:
        return Icons.hexagon_outlined;
    }
  }

  Color get accent {
    switch (this) {
      case GameplayMode.water:
        return const Color(0xFF0284C7);
      case GameplayMode.star:
        return const Color(0xFFEAB308);
      case GameplayMode.geometric:
        return const Color(0xFF7C3AED);
    }
  }

  String get semanticLabel {
    switch (this) {
      case GameplayMode.water:
        return 'Water mode';
      case GameplayMode.star:
        return 'Star mode';
      case GameplayMode.geometric:
        return 'Geometric mode';
    }
  }
}
