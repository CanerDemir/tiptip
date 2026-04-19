import 'package:flutter/material.dart';

import 'tiptip_colors.dart';
import 'tiptip_dimens.dart';

/// 3 katmanlı yüzey sistemi:
/// - **Level 0:** [TiptipColors.background] — uygulama zemini (Scaffold).
/// - **Level 1:** Hafif gölgeli kartlar ve konteynerler.
/// - **Level 2:** Yüksek gölge + turkuaz parlama — birincil / aktif etkileşimler.
abstract final class TiptipSurfaces {
  TiptipSurfaces._();

  static BorderRadius get borderRadius =>
      BorderRadius.circular(TiptipDimens.radius);

  /// Level 1 — kart ve panel gölgesi (yumuşak, düşük yükseltme).
  static List<BoxShadow> get level1Shadows => <BoxShadow>[
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  /// Level 2 — belirgin gölge + mavi-turkuaz parlama (aktif buton, öne çıkan CTA).
  static List<BoxShadow> level2Shadows({Color? glowColor}) {
    final Color glow = glowColor ?? TiptipColors.accentTurquoise;
    return <BoxShadow>[
      BoxShadow(
        color: glow.withValues(alpha: 0.45),
        blurRadius: 20,
        spreadRadius: 0,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ];
  }

  /// Level 1 kart dekorasyonu.
  static BoxDecoration level1Card({Color? color, Border? border}) =>
      BoxDecoration(
        color: color ?? TiptipColors.surfaceLevel1,
        borderRadius: borderRadius,
        border: border,
        boxShadow: level1Shadows,
      );

  /// Level 2 — gradyanlı yüzey + parlama (ör. dolu buton, öne çıkan tile).
  static BoxDecoration level2Active({Gradient? gradient, Border? border}) =>
      BoxDecoration(
        gradient: gradient ?? TiptipColors.accentGradient,
        borderRadius: borderRadius,
        border: border,
        boxShadow: level2Shadows(),
      );
}
