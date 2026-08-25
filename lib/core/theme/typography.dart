import 'package:flutter/material.dart';
import 'colors.dart';

/// VoltEZ Typography
/// Both Person 1 and Person 2 MUST use these text styles.
abstract final class AppTypography {
  // ─── Font Family ───
  static const String _fontFamily = 'Inter';

  // ─── Display / Hero ───
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.1,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
    height: 1.15,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  // ─── Headlines ───
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  // ─── Body ───
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // ─── Labels / Tags ───
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: AppColors.textMuted,
  );

  // ─── Button Text ───
  static const TextStyle buttonText = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
  );

  static const TextStyle buttonTextSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
  );

  // ─── Section Header (numbered sections like "01 — TODAY AT A GLANCE") ───
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.4,
    color: AppColors.textMuted,
  );

  static const TextStyle sectionNumber = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
  );
}
