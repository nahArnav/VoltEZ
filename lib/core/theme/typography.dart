import 'package:flutter/material.dart';
import 'colors.dart';

/// VoltEZ Typography — "Vibrant Professionalism"
/// Dual-font strategy: Outfit (headlines) + Inter (body/labels)
/// Both Person 1 and Person 2 MUST use these text styles.
abstract final class AppTypography {
  // ─── Font Families ───
  static const String _fontHeadline = 'Outfit';
  static const String _fontBody = 'Inter';

  // ─── Display / Hero (Outfit) ───
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontHeadline,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontHeadline,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: _fontHeadline,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.01,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  // ─── Headlines (Outfit) ───
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontHeadline,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.33,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontHeadline,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _fontHeadline,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.375,
  );

  // ─── Body (Inter) ───
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontBody,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.56,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontBody,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.43,
  );

  // ─── Labels / Tags (Inter, Bold) ───
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.05,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.05,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.05,
    color: AppColors.textMuted,
  );

  // ─── Button Text (Inter, Bold) ───
  static const TextStyle buttonText = TextStyle(
    fontFamily: _fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.05,
  );

  static const TextStyle buttonTextSmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.05,
  );

  // ─── Section Header (numbered sections like "01 — TODAY AT A GLANCE") ───
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.05,
    color: AppColors.textSecondary,
  );

  static const TextStyle sectionNumber = TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );
}
