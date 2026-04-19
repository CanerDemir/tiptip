import 'package:flutter/material.dart';

/// TıpTıp renk paleti ve vurgu gradyanı.
abstract final class TiptipColors {
  TiptipColors._();

  /// Level 0 — ana arka plan (fildişi).
  static const Color background = Color(0xFFFFFDF5);

  /// Birincil metin rengi (koyu gri).
  static const Color textPrimary = Color(0xFF333333);

  /// İkincil / daha düşük kontrast metinler.
  static const Color textSecondary = Color(0x80333333);

  /// Gradyanın başlangıç tonu (canlı turkuaz).
  static const Color accentTurquoise = Color(0xFF06B6D4);

  /// Gradyanın bitiş tonu (canlı mavi).
  static const Color accentBlue = Color(0xFF2563EB);

  /// Kart ve yüzeyler için hafif nötr üst yüzey.
  static const Color surfaceLevel1 = Color(0xFFFFFFFF);

  /// Gradyan üzerindeki metin / ikon rengi.
  static const Color onAccent = Color(0xFFFFFFFF);

  /// Vurgu gradyanı — butonlar ve güçlü aksanlar için.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[accentTurquoise, accentBlue],
  );

  /// Hafif vurgu alanları (chip, seçili sekme vb.) için düşük opaklık.
  static Color accentOverlay(double opacity) =>
      accentBlue.withValues(alpha: opacity);
}
