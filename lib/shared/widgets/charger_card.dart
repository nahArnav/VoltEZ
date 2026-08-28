import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../models/models.dart';
import 'status_chip.dart';

/// Charger card — used on Driver side (nearby chargers, search results)
/// and Business side (charger fleet list).
///
/// When [glass] is true, uses glassmorphism with [accentColor] gradient tint.
class ChargerCard extends StatelessWidget {
  const ChargerCard({
    super.key,
    required this.name,
    required this.power,
    required this.price,
    required this.status,
    this.address,
    this.rating,
    this.amenities,
    this.onTap,
    this.trailing,
    this.showAddress = true,
    this.glass = false,
    this.accentColor,
  });

  final String name;
  final String power;
  final String price;
  final ChargerStatus status;
  final String? address;
  final double? rating;
  final List<String>? amenities;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showAddress;

  /// Enable glassmorphism effect.
  final bool glass;

  /// Accent color for the glass gradient. Defaults to [AppColors.primary].
  final Color? accentColor;

  Color get _accent => accentColor ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    if (glass) return _buildGlassCard();
    return _buildSolidCard();
  }

  // ─── Gradient variant (matches View Details button) ───
  Widget _buildGlassCard() {
    // Build a gradient from _accent to a lighter shade of the same hue
    final hsl = HSLColor.fromColor(_accent);
    final lighter = hsl.withLightness((hsl.lightness + 0.22).clamp(0.0, 1.0)).toColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accent, lighter],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: _buildContent(),
      ),
    );
  }

  // ─── Solid variant (existing) ───
  Widget _buildSolidCard() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final nameColor = glass ? AppColors.onPrimary : AppColors.textPrimary;
    final subColor = glass ? AppColors.onPrimary.withValues(alpha: 0.6) : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header: icon + name + status ───
        Row(
          children: [
            _ChargerAvatar(status: status, glass: glass, accent: _accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.headlineSmall.copyWith(color: nameColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showAddress && address != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      address!,
                      style: AppTypography.bodySmall.copyWith(color: subColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            StatusChip(status: status),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Metrics Row ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Metric(icon: Icons.bolt, value: power, label: 'kW', glass: glass, accent: _accent),
            _Metric(
              icon: Icons.currency_rupee,
              value: price,
              label: '/kWh',
              glass: glass,
              accent: _accent,
            ),
            if (rating != null)
              _Metric(
                icon: Icons.star_rounded,
                value: rating!.toStringAsFixed(1),
                label: 'Rating',
                glass: glass,
                accent: _accent,
              ),
          ],
        ),

        // ─── Amenities ───
        if (amenities != null && amenities!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: amenities!
                .map(
                  (a) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: glass
                          ? AppColors.onPrimary.withValues(alpha: 0.15)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(a, style: AppTypography.bodySmall.copyWith(
                      color: glass ? AppColors.onPrimary.withValues(alpha: 0.8) : AppColors.textSecondary,
                    )),
                  ),
                )
                .toList(),
          ),
        ],

        // ─── Trailing action ───
        if (trailing != null) ...[
          const SizedBox(height: 14),
          trailing!,
        ],
      ],
    );
  }
}

class _ChargerAvatar extends StatelessWidget {
  const _ChargerAvatar({required this.status, this.glass = false, this.accent});
  final ChargerStatus status;
  final bool glass;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: glass ? AppColors.onPrimary.withValues(alpha: 0.2) : null,
        gradient: glass ? null : LinearGradient(
          colors: [
            color.withValues(alpha: 0.35),
            AppColors.secondary.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Icon(
        Icons.ev_station_rounded,
        color: glass ? AppColors.onPrimary : color,
        size: 28,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    this.glass = false,
    this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool glass;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    final textColor = glass ? AppColors.onPrimary : AppColors.textPrimary;
    final labelColor = glass ? AppColors.onPrimary.withValues(alpha: 0.6) : AppColors.textSecondary;
    return Column(
      children: [
        Icon(icon, color: glass ? AppColors.onPrimary.withValues(alpha: 0.8) : color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTypography.headlineSmall.copyWith(
            color: textColor,
          ),
        ),
        Text(label, style: AppTypography.labelMedium.copyWith(
          color: labelColor,
        )),
      ],
    );
  }
}
