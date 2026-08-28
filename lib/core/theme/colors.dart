import 'package:flutter/material.dart';

/// VoltEZ Official Color Palette — "Vibrant Professionalism"
/// Both Person 1 (Driver) and Person 2 (Business) MUST use these colors.
///
/// Design system: High-Contrast Modern
/// Primary: Leaf Green (#2D6A4F) — growth, success, primary actions
/// Secondary: Ocean Blue (#1D3557) — professional foundation, navigation
/// Accent: Marigold (#FFB703) — highlights, warnings
/// Tertiary: Coral (#E76F51) — secondary CTAs, status indicators
abstract final class AppColors {
  // ─── Surfaces (Light Theme) ───
  static const Color background = Color(0xFFF8F9FA); // Surface
  static const Color backgroundDim = Color(0xFFD9DADB); // Surface Dim
  static const Color card = Color(0xFFFFFFFF); // Card (White)
  static const Color surface = Color(0xFFF3F4F5); // Surface Container Low
  static const Color surfaceContainer = Color(0xFFEDEEEF); // Surface Container
  static const Color surfaceContainerHigh = Color(0xFFE7E8E9); // Surface Container High
  static const Color surfaceLight = Color(0xFFF3F4F5); // For hover / pressed states

  // ─── Primary: Forest Green ───
  static const Color primary = Color(0xFF14532D); // Deep Forest Green
  static const Color primaryDim = Color(0xFF40916C); // Lighter Green
  static const Color primaryContainer = Color(0xFFA8E7C5); // Mint Container
  static const Color onPrimary = Color(0xFFFFFFFF); // White on green

  // ─── Secondary: Ocean Blue ───
  static const Color secondary = Color(0xFF1D3557); // Ocean Blue
  static const Color secondarySoft = Color(0xFF28477A); // Lighter Blue
  static const Color secondaryContainer = Color(0xFFBBD3FD); // Blue Container
  static const Color onSecondary = Color(0xFFFFFFFF); // White on blue

  // ─── Tertiary / Accent ───
  static const Color marigold = Color(0xFFFFB703); // Marigold Yellow
  static const Color coral = Color(0xFFE76F51); // Coral Red

  // ─── Status Colors ───
  static const Color success = Color(0xFF14532D); // Green (same as primary)
  static const Color warning = Color(0xFFFFB703); // Marigold (same as marigold)
  static const Color error = Color(0xFFBA1A1A); // Material Error Red
  static const Color info = Color(0xFF1D3557); // Ocean Blue (same as secondary)

  // ─── Text (High Contrast on Light) ───
  static const Color textPrimary = Color(0xFF191C1D); // On Surface (Dark Charcoal)
  static const Color textSecondary = Color(0xFF404943); // On Surface Variant
  static const Color textMuted = Color(0xFF707973); // Outline
  static const Color textOnPrimary = Color(0xFFFFFFFF); // White on primary
  static const Color textOnCard = Color(0xFF191C1D); // Dark text on white card

  // ─── Borders & Dividers ───
  static const Color border = Color(0xFFBFC9C1); // Outline Variant (Green-tinted)
  static const Color borderLight = Color(0xFFE1E3E4); // Surface Variant
  static const Color divider = Color(0xFFBFC9C1); // Outline Variant

  // ─── Status Colors (backward-compat aliases) ───
  static Color get available => success;
  static Color get busy => warning;
  static Color get offline => textMuted;
  static Color get charging => primary;

  // ─── Gradient Presets ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDim],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient oceanGradient = LinearGradient(
    colors: [secondarySoft, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [card, surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Legacy aliases for existing screens ───
  static const Color backgroundDark = background;
}
