import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/network/session_api.dart';
import '../../../shared/widgets/widgets.dart';

/// Charging session flow — fully driven by [SessionProvider].
///
/// Phases:
/// 1. Check In — arrival confirmation with booking details
/// 2. Live Charging — real-time battery/power/energy/cost dashboard
/// 3. Complete — session summary with rating
/// 4. Thank You — after rating submitted
class ChargingSessionScreen extends StatefulWidget {
  const ChargingSessionScreen({super.key});

  @override
  State<ChargingSessionScreen> createState() => _ChargingSessionScreenState();
}

class _ChargingSessionScreenState extends State<ChargingSessionScreen>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  String? _selectedIssue;
  final _feedbackController = TextEditingController();

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Wire up booking context if coming from booking confirmation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionProvider>();
      final booking = context.read<BookingProvider>();
      if (session.bookingId == null && booking.confirmedBooking != null) {
        session.setBookingId(booking.confirmedBooking!.bookingId);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Consumer<SessionProvider>(
          builder: (context, session, _) {
            final showBack = session.phase == SessionPhase.idle ||
                session.phase == SessionPhase.checkingIn ||
                session.phase == SessionPhase.error;
            return showBack
                ? IconButton(
                    onPressed: () => context.go('/driver/home'),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary, size: 24),
                  )
                : const SizedBox.shrink();
          },
        ),
        title: Consumer<SessionProvider>(
          builder: (context, session, _) {
            return Text(
              _titleForPhase(session.phase),
              style: AppTypography.headlineLarge.copyWith(fontSize: 18),
            );
          },
        ),
        centerTitle: false,
        actions: [
          // Connection indicator
          Consumer<SessionProvider>(
            builder: (context, session, _) {
              if (session.phase != SessionPhase.charging &&
                  session.phase != SessionPhase.checkedIn) {
                return const SizedBox.shrink();
              }
              return _buildConnectionBadge(session.connectionStateLabel);
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Consumer<SessionProvider>(
        builder: (context, session, _) {
          return switch (session.phase) {
            SessionPhase.idle => _buildIdle(context),
            SessionPhase.checkingIn => _buildCheckingIn(),
            SessionPhase.checkedIn => _buildCheckedIn(context, session),
            SessionPhase.charging => _buildCharging(context, session),
            SessionPhase.ending => _buildEnding(),
            SessionPhase.complete => _buildComplete(session),
            SessionPhase.rated => _buildThankYou(),
            SessionPhase.error => _buildError(context, session),
          };
        },
      ),
    );
  }

  String _titleForPhase(SessionPhase phase) => switch (phase) {
        SessionPhase.idle => 'Check In',
        SessionPhase.checkingIn => 'Checking In',
        SessionPhase.checkedIn => 'Ready to Charge',
        SessionPhase.charging => 'Charging',
        SessionPhase.ending => 'Ending Session',
        SessionPhase.complete => 'Session Complete',
        SessionPhase.rated => 'Thank You',
        SessionPhase.error => 'Error',
      };

  // ═══════════════════════════════════════════════════════════════════════════
  // CONNECTION BADGE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildConnectionBadge(String state) {
    final isLive = state == 'Live';
    final color = isLive ? AppColors.success : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            state,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE: IDLE — Pre-check-in
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildIdle(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Charger illustration
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.ev_station_rounded,
                color: AppColors.primary,
                size: 64,
              ),
            ),
            const SizedBox(height: 28),
            Text('Ready to charge?', style: AppTypography.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Plug in your vehicle and confirm check-in.\n'
              'Make sure the connector is securely attached.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 32),

            // Booking info card (from BookingProvider if available)
            Consumer<BookingProvider>(
              builder: (context, booking, _) {
                final confirmed = booking.confirmedBooking;
                if (confirmed == null) {
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'No active booking found.',
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          text: 'FIND A CHARGER',
                          onPressed: () => context.go('/driver/map'),
                          isExpanded: true,
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Charger', confirmed.chargerName),
                      _infoRow('Connector',
                          '${confirmed.connectorType} · ${confirmed.powerKw.round()} kW'),
                      _infoRow(
                          'Slot', '${confirmed.startTime} – ${confirmed.endTime}'),
                      _infoRow('Date', confirmed.date),
                      _infoRow(
                        'Est. Cost',
                        '₹${confirmed.estimatedCost.round()}',
                        highlight: true,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            PrimaryButton(
              text: 'CHECK IN',
              onPressed: () => context.read<SessionProvider>().checkIn(),
              isExpanded: true,
              icon: Icons.check_circle_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE: CHECKING IN
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCheckingIn() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text('Checking in...', style: AppTypography.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Verifying your booking with the charger',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE: CHECKED IN — Ready to start charging
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCheckedIn(BuildContext context, SessionProvider session) {
    final data = session.sessionData;
    if (data == null) return const SizedBox.shrink();
    final isCashBooking = context
            .read<BookingProvider>()
            .confirmedBooking
            ?.paymentMethod
            ?.toLowerCase() ==
        'cash';

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.15),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 56),
            ),
            const SizedBox(height: 24),
            Text('Checked In!', style: AppTypography.displaySmall),
            const SizedBox(height: 8),
            Text(
              'You\'re at the charger. Plug in and start charging.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 28),

            // Session details card
            _buildSessionInfoCard(data),
            const SizedBox(height: 32),

            if (isCashBooking) ...[
              Text(
                'Show your start code to the host. Charging begins after they verify it.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: 'REFRESH STATUS',
                onPressed: () => session.refreshStatus(),
                isExpanded: true,
                icon: Icons.refresh_rounded,
                height: 52,
              ),
            ] else
              PrimaryButton(
                text: 'START CHARGING',
                onPressed: () => session.startCharging(),
                isExpanded: true,
                icon: Icons.bolt_rounded,
                height: 56,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard(SessionData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _infoRow('Charger', data.chargerName),
          _infoRow('Connector',
              '${data.connectorType} · ${data.powerKw.round()} kW'),
          _infoRow('Slot', '${data.slotStart} – ${data.slotEnd}'),
          _infoRow('Cost', '₹${data.costPerKwh.round()}/kWh'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE: CHARGING — Live dashboard
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCharging(BuildContext context, SessionProvider session) {
    final data = session.sessionData;
    if (data == null) return const SizedBox.shrink();

    final soc = data.batteryPercent;
    final socColor = soc > 50
        ? AppColors.success
        : soc > 20
            ? AppColors.warning
            : AppColors.error;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Live indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, _) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(
                      alpha: 0.12 + _pulseController.value * 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CHARGING IN PROGRESS',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 28),

          // Battery SOC — hero section
          _buildBatteryHero(soc, socColor, data),
          const SizedBox(height: 24),

          // Session info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.ev_station_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.chargerName,
                          style: AppTypography.headlineSmall
                              .copyWith(fontSize: 14)),
                      Text(
                        '${data.connectorType} · ${data.powerKw.round()} kW',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  session.formattedElapsed,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Live metrics grid
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _liveMetric(
                      Icons.bolt_rounded,
                      '${data.energyKwh.toStringAsFixed(2)} kWh',
                      'Energy',
                      AppColors.primary,
                    ),
                    const SizedBox(width: 16),
                    _liveMetric(
                      Icons.speed_rounded,
                      '${data.currentPowerKw.round()} kW',
                      'Power',
                      AppColors.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _liveMetric(
                      Icons.currency_rupee,
                      '₹${data.runningCost.toStringAsFixed(0)}',
                      'Running Cost',
                      AppColors.success,
                    ),
                    const SizedBox(width: 16),
                    _liveMetric(
                      Icons.timer_outlined,
                      '${data.estimatedRemainingMinutes} min',
                      'Remaining',
                      AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // End session button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _showEndSessionDialog(context, session),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('END SESSION'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryHero(double soc, Color color, SessionData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.2),
            AppColors.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('BATTERY', style: AppTypography.labelSmall.copyWith(color: color)),
              Text(
                'CHARGING',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${soc.round()}%',
            style: TextStyle(
              color: color,
              fontSize: 56,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: soc / 100,
              color: color,
              backgroundColor: AppColors.surface,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Session: ${data.slotStart} – ${data.slotEnd}',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _liveMetric(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.labelMedium),
          ],
        ),
      ),
    );
  }

  void _showEndSessionDialog(BuildContext context, SessionProvider session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('End Session?',
            style: AppTypography.headlineMedium),
        content: Text(
          'Are you sure you want to end the charging session? '
          'You will be charged for the energy consumed so far.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              session.endSession();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('END SESSION'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE: ENDING
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEnding() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 24),
          Text('Ending session...', style: AppTypography.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Finalizing your charging session',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE: COMPLETE — Summary + Rating
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildComplete(SessionProvider session) {
    final summary = session.sessionSummary;
    if (summary == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 48),
          ),
          const SizedBox(height: 20),
          Text('Charging Complete!',
              style: AppTypography.displaySmall
                  .copyWith(color: AppColors.success)),
          const SizedBox(height: 24),

          // Session summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _infoRow('Duration', '${summary.durationMinutes} min'),
                _infoRow('Energy', '${summary.energyKwh.toStringAsFixed(1)} kWh'),
                _infoRow(
                  'Total Cost',
                  '₹${summary.totalCost.toStringAsFixed(0)}',
                  highlight: true,
                ),
                _infoRow('Charger', summary.chargerName),
                _infoRow('Connector', summary.connectorType),
                _infoRow('Date', summary.date),
                _infoRow('Time', '${summary.startTime} – ${summary.endTime}'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Rating
          Text('Rate your experience', style: AppTypography.headlineMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    i < _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 44,
                    color: i < _rating
                        ? AppColors.warning
                        : AppColors.textMuted,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Issue report (shown when low rating)
          if (_rating > 0 && _rating <= 2) ...[
            _buildIssueReport(),
            const SizedBox(height: 24),
          ],

          PrimaryButton(
            text: 'SUBMIT & FINISH',
            onPressed: _rating > 0
                ? () => session.submitRating(
                      rating: _rating,
                      issueCategory: _selectedIssue,
                      feedback: _feedbackController.text.isNotEmpty
                          ? _feedbackController.text
                          : null,
                    )
                : null,
            isExpanded: true,
          ),

          if (_rating == 0) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => session.skipRating(),
              child: Text(
                'Skip rating',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIssueReport() {
    final issues = [
      'Charger unavailable',
      'Charger malfunction',
      'Incorrect availability',
      'Payment issue',
      'Other',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What went wrong?',
            style:
                AppTypography.headlineSmall.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: issues.map((issue) {
              final selected = _selectedIssue == issue;
              return GestureDetector(
                onTap: () => setState(() => _selectedIssue = issue),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.error.withValues(alpha: 0.15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.error : AppColors.border,
                    ),
                  ),
                  child: Text(
                    issue,
                    style: TextStyle(
                      color: selected
                          ? AppColors.error
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _feedbackController,
            hintText: 'Additional details (optional)',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE: THANK YOU
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildThankYou() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 40),
            Icon(Icons.favorite_rounded,
                color: AppColors.primary, size: 64),
            const SizedBox(height: 24),
            Text('Thank you!', style: AppTypography.displaySmall),
            const SizedBox(height: 12),
            Text(
              'Your feedback helps improve\nthe VoltEZ network.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 48),
            PrimaryButton(
              text: 'BACK TO HOME',
              onPressed: () {
                context.read<SessionProvider>().reset();
                context.go('/driver/home');
              },
              isExpanded: true,
              icon: Icons.home_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE: ERROR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildError(BuildContext context, SessionProvider session) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 56),
            const SizedBox(height: 20),
            Text('Something went wrong',
                style: AppTypography.headlineMedium),
            const SizedBox(height: 10),
            Text(
              session.errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'RETRY',
              onPressed: () {
                session.reset();
                // Re-wire booking context
                final booking = context.read<BookingProvider>();
                if (booking.confirmedBooking != null) {
                  session
                      .setBookingId(booking.confirmedBooking!.bookingId);
                }
                session.checkIn();
              },
              icon: Icons.refresh_rounded,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.go('/driver/home'),
              child: Text(
                'Back to Home',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Shared helpers ───
  Widget _infoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall),
          Text(
            value,
            style: highlight
                ? AppTypography.headlineSmall
                    .copyWith(color: AppColors.primary)
                : AppTypography.headlineSmall.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
