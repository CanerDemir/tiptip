import 'package:flutter/material.dart';

import 'tiptip_colors.dart';
import 'tiptip_dimens.dart';
import 'tiptip_surfaces.dart';
import 'tiptip_typography.dart';

/// TıpTıp uygulama teması — renkler, fontlar, 24px köşe ve yüzey hiyerarşisi.
abstract final class TiptipTheme {
  TiptipTheme._();

  static ThemeData get light {
    final ColorScheme colorScheme = ColorScheme.light(
      primary: TiptipColors.accentBlue,
      onPrimary: TiptipColors.onAccent,
      primaryContainer: TiptipColors.accentTurquoise.withValues(alpha: 0.25),
      onPrimaryContainer: TiptipColors.textPrimary,
      secondary: TiptipColors.accentTurquoise,
      onSecondary: TiptipColors.onAccent,
      surface: TiptipColors.surfaceLevel1,
      onSurface: TiptipColors.textPrimary,
      surfaceContainerHighest: TiptipColors.background,
      outline: TiptipColors.textPrimary.withValues(alpha: 0.12),
      shadow: Colors.black,
    );

    final RoundedRectangleBorder shape24 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TiptipDimens.radius),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: TiptipColors.background,
      textTheme: TiptipTypography.textTheme(colorScheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: TiptipColors.background,
        foregroundColor: TiptipColors.textPrimary,
        titleTextStyle: TiptipTypography.textTheme(colorScheme).titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: TiptipColors.surfaceLevel1,
        shadowColor: Colors.transparent,
        shape: shape24,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        shape: shape24,
        backgroundColor: TiptipColors.surfaceLevel1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: shape24,
        backgroundColor: TiptipColors.surfaceLevel1,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape24,
      ),
      chipTheme: ChipThemeData(
        shape: shape24,
        side: BorderSide.none,
        backgroundColor: TiptipColors.accentBlue.withValues(alpha: 0.08),
        labelStyle: TiptipTypography.textTheme(colorScheme).labelLarge!,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: TiptipColors.surfaceLevel1,
        indicatorShape: shape24,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          foregroundColor: TiptipColors.onAccent,
          backgroundColor: TiptipColors.accentBlue,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: shape24,
          textStyle: TiptipTypography.textTheme(colorScheme).labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 4,
          shadowColor: TiptipSurfaces.level2Shadows().first.color,
          foregroundColor: TiptipColors.onAccent,
          backgroundColor: TiptipColors.accentBlue,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: shape24,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TiptipColors.accentBlue,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: shape24,
          side: BorderSide(
            color: TiptipColors.accentBlue.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TiptipColors.accentBlue,
          shape: shape24,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TiptipColors.surfaceLevel1,
        border: OutlineInputBorder(borderRadius: TiptipSurfaces.borderRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: TiptipSurfaces.borderRadius,
          borderSide: BorderSide(
            color: TiptipColors.textPrimary.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TiptipSurfaces.borderRadius,
          borderSide: const BorderSide(
            color: TiptipColors.accentTurquoise,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: TiptipColors.accentBlue,
        foregroundColor: TiptipColors.onAccent,
        shape: shape24,
        elevation: 6,
      ),
      listTileTheme: ListTileThemeData(
        shape: shape24,
        tileColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: TiptipColors.textPrimary.withValues(alpha: 0.08),
        thickness: 1,
      ),
    );
  }
}
