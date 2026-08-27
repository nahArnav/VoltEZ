import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../models/models.dart';
import 'status_chip.dart';

/// Charger card — used on Driver side (nearby chargers, search results)
/// and Business side (charger fleet list).
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

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header: icon + name + status ───
            Row(
              children: [
                _ChargerAvatar(status: status),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showAddress && address != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          address!,
                          style: AppTypography.bodySmall,
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
                _Metric(icon: Icons.bolt, value: power, label: 'kW'),
                _Metric(
                  icon: Icons.currency_rupee,
                  value: price,
                  label: '/kWh',
                ),
                if (rating != null)
                  _Metric(
                    icon: Icons.star_rounded,
                    value: rating!.toStringAsFixed(1),
                    label: 'Rating',
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(a, style: AppTypography.bodySmall),
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
        ),
      ),
    );
  }
}

class _ChargerAvatar extends StatelessWidget {
  const _ChargerAvatar({required this.status});
  final ChargerStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.35),
            AppColors.secondary.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Icon(
        Icons.ev_station_rounded,
        color: AppColors.primary,
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
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        Text(label, style: AppTypography.labelMedium),
      ],
    );
  }
}
