import 'package:flutter/material.dart';

/// VoltEZ Official Color Palette
/// Both Person 1 (Driver) and Person 2 (Business) MUST use these colors.
abstract final class AppColors {
  // ─── Backgrounds ───
  static const Color background = Color(0xFF0A0F1F); // Midnight Navy
  static const Color card = Color(0xFF111827); // Graphite
  static const Color surface = Color(0xFF1A2332); // Slightly lighter than card
  static const Color surfaceLight = Color(0xFF1E293B); // For hover / pressed states

  // ─── Accents ───
  static const Color primary = Color(0xFF00E5FF); // Electric Cyan
  static const Color secondary = Color(0xFF3B82F6); // Ion Blue
  static const Color success = Color(0xFF34D399); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF6366F1); // Indigo

  // ─── Text ───
  static const Color textPrimary = Color(0xFFF3F4F6); // Soft White
  static const Color textSecondary = Color(0xFF94A3B8); // Cool Grey
  static const Color textMuted = Color(0xFF64748B); // Dimmer Grey
  static const Color textOnPrimary = Color(0xFF0A0F1F); // Dark text on cyan

  // ─── Borders & Dividers ───
  static const Color border = Color(0xFF1E293B);
  static const Color borderLight = Color(0xFF334155);
  static const Color divider = Color(0xFF1E293B);

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
    colors: [success, Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [card, surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
