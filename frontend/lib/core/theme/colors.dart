import 'package:flutter/material.dart';

/// VoltEZ official palette.
///
/// The five anchor colours come from the product palette supplied by the
/// team: deep teal, bright teal, antique gold, warm cream, and espresso brown.
/// Derived shades are deliberately kept close to those anchors for readable
/// contrast on mobile screens.
abstract final class AppColors {
  // ─── Backgrounds ───
  static const Color background = Color(0xFF0B4F4A); // Deep teal
  static const Color card = Color(0xFF083F3C); // Deep teal shade
  static const Color surface = Color(0xFF0F766E); // Bright teal
  static const Color surfaceLight = Color(0xFF238A81); // Pressed/hover state

  // ─── Accents ───
  static const Color primary = Color(0xFFBFA054); // Antique gold
  static const Color secondary = Color(0xFF5C3D2E); // Espresso brown
  static const Color success = Color(0xFF83C6B0); // Readable teal-green
  static const Color warning = Color(0xFFBFA054); // Antique gold
  static const Color error = Color(0xFFD7795B); // Warm terracotta
  static const Color info = Color(0xFF6FA9A0); // Muted teal

  // ─── Text ───
  static const Color textPrimary = Color(0xFFF3EFE6); // Warm cream
  static const Color textSecondary = Color(0xFFD8D2C4); // Soft cream
  static const Color textMuted = Color(0xFFAAB6A9); // Muted sage
  static const Color textOnPrimary = Color(0xFF2D211B); // Brown on gold

  // ─── Borders & Dividers ───
  static const Color border = Color(0xFF1D625C);
  static const Color borderLight = Color(0xFF5D8F86);
  static const Color divider = Color(0xFF185852);

  // ─── Status Colors (with opacity variants) ───
  static Color get available => success;
  static Color get busy => warning;
  static Color get offline => textMuted;
  static Color get charging => primary;

  // ─── Gradient Presets ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [card, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
