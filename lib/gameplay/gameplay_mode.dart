import 'package:flutter/material.dart';

enum GameplayMode {
  water,
  star,
  jelly,
  musicalRain,
  floralBloom,
  magneticDust,
}

extension GameplayModeVisual on GameplayMode {
  IconData get icon {
    switch (this) {
      case GameplayMode.water:
        return Icons.water_drop_rounded;
      case GameplayMode.star:
        return Icons.star_rounded;
      case GameplayMode.jelly:
        return Icons.bubble_chart_rounded;
      case GameplayMode.musicalRain:
        return Icons.music_note_rounded;
      case GameplayMode.floralBloom:
        return Icons.local_florist_rounded;
      case GameplayMode.magneticDust:
        return Icons.blur_on_rounded;
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
      case GameplayMode.musicalRain:
        return const Color(0xFF14B8A6);
      case GameplayMode.floralBloom:
        return const Color(0xFFE879A9);
      case GameplayMode.magneticDust:
        return const Color(0xFF8B7EC8);
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
      case GameplayMode.musicalRain:
        return 'Musical rain mode';
      case GameplayMode.floralBloom:
        return 'Floral bloom mode';
      case GameplayMode.magneticDust:
        return 'Magnetic dust mode';
    }
  }
}
