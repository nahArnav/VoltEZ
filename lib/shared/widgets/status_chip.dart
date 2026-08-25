import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../models/models.dart';

/// Status chip — shows colored badge for charger/booking status.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.text,
  });

  final ChargerStatus status;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ChargerStatus.available => ('AVAILABLE', AppColors.success),
      ChargerStatus.busy => ('IN USE', AppColors.warning),
      ChargerStatus.offline => ('OFFLINE', AppColors.textMuted),
      ChargerStatus.maintenance => ('MAINTENANCE', AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text ?? label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Booking status chip — different set of statuses.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({
    super.key,
    required this.status,
  });

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BookingStatus.pending => ('PENDING', AppColors.warning),
      BookingStatus.confirmed => ('CONFIRMED', AppColors.success),
      BookingStatus.held => ('HELD', AppColors.primary),
      BookingStatus.active => ('ACTIVE', AppColors.primary),
      BookingStatus.completed => ('COMPLETED', AppColors.success),
      BookingStatus.cancelled => ('CANCELLED', AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
