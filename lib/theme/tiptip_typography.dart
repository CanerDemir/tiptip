import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tiptip_colors.dart';

/// Başlıklar: **Manrope**, gövde: **Inter**.
abstract final class TiptipTypography {
  TiptipTypography._();

  static TextTheme textTheme(ColorScheme colors) {
    final TextStyle manropeBase = GoogleFonts.manrope(
      color: TiptipColors.textPrimary,
      height: 1.25,
    );
    final TextStyle interBase = GoogleFonts.inter(
      color: TiptipColors.textPrimary,
      height: 1.45,
    );

    return TextTheme(
      displayLarge: manropeBase.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      displayMedium: manropeBase.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: manropeBase.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: manropeBase.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: manropeBase.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: manropeBase.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: manropeBase.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: manropeBase.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      titleSmall: manropeBase.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      bodyLarge: interBase.copyWith(fontSize: 16, letterSpacing: 0.5),
      bodyMedium: interBase.copyWith(fontSize: 14, letterSpacing: 0.25),
      bodySmall: interBase.copyWith(
        fontSize: 12,
        letterSpacing: 0.4,
        color: TiptipColors.textSecondary,
      ),
      labelLarge: interBase.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: interBase.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      labelSmall: interBase.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: TiptipColors.textSecondary,
      ),
    ).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface);
  }
}
