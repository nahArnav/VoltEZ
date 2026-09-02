import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/network/api_service.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/address_formatter.dart';

/// Live owner workspace. Every number and list on this screen comes from the
/// authenticated business APIs; an empty account is shown as an empty state,
/// never as a demo business or fabricated charger.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _selectedIndex = widget.initialTab.clamp(0, 4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BusinessProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, business, _) {
        if (business.isLoading && business.business == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (business.needsOnboarding) {
          return _BusinessOnboarding(onCreated: business.load);
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                _OverviewPage(),
                _ChargersPage(),
                _BookingsPage(),
                _AnalyticsPage(),
                _ProfilePage(),
              ],
            ),
          ),
          bottomNavigationBar: _BottomNav(
            selectedIndex: _selectedIndex,
            onChanged: (index) => setState(() => _selectedIndex = index),
          ),
        );
      },
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    final business = provider.business ?? const <String, dynamic>{};
    final metrics = provider.dashboard;
    final name = business['name']?.toString().trim();
    final reviews = _listOfMaps(metrics['reviews']);
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _PageHeader(
            eyebrow: 'VOLTEZ / BUSINESS',
            title: (name == null || name.isEmpty) ? 'Your business' : name,
            subtitle: 'Live operations overview',
            icon: Icons.notifications_none_rounded,
            onIconTap: () => _showBusinessNotifications(context),
          ),
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: provider.errorMessage!),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('TODAY AT A GLANCE'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _MetricCard(
                label: 'TOTAL EARNINGS',
                value: _rupees(metrics['total_earnings']),
                icon: Icons.currency_rupee_rounded,
                color: AppColors.primary,
              ),
              _MetricCard(
                label: 'SESSIONS',
                value: _number(metrics['sessions']),
                icon: Icons.bolt_rounded,
                color: AppColors.marigold,
              ),
              _MetricCard(
                label: 'ACTIVE CHARGERS',
                value:
                    '${_number(provider.displayedActiveChargerCount)}/${_number(provider.displayedChargerCount)}',
                icon: Icons.ev_station_rounded,
                color: AppColors.secondary,
              ),
              _MetricCard(
                label: 'ACTIVE TIME',
                value: _minutes(metrics['active_minutes']),
                icon: Icons.timer_outlined,
                color: AppColors.coral,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('YOUR CHARGERS'),
          const SizedBox(height: 12),
          _ChargerList(provider.chargers),
          const SizedBox(height: 24),
          const _SectionTitle('RECENT CONFIRMED BOOKINGS'),
          const SizedBox(height: 12),
          _BookingList(provider.bookings, allowCancel: false),
          const SizedBox(height: 24),
          const _SectionTitle('DRIVER REVIEWS'),
          const SizedBox(height: 12),
          _ReviewList(reviews),
        ],
      ),
    );
  }
}

class _ChargersPage extends StatelessWidget {
  const _ChargersPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _PageHeader(
            eyebrow: 'FLEET',
            title: 'Chargers',
            subtitle: 'Manage live station status and tariffs',
            icon: Icons.ev_station_rounded,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _showAddCharger(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('REGISTER CHARGER'),
          ),
          const SizedBox(height: 14),
          _ChargerList(provider.chargers, showControls: true),
        ],
      ),
    );
  }
}

class _BookingsPage extends StatelessWidget {
  const _BookingsPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _PageHeader(
            eyebrow: 'RESERVATIONS',
            title: 'Bookings',
            subtitle:
                'Confirmed reservations currently actionable by your fleet',
            icon: Icons.calendar_today_rounded,
          ),
          const SizedBox(height: 18),
          _BookingList(provider.bookings, allowCancel: true),
        ],
      ),
    );
  }
}

class _AnalyticsPage extends StatelessWidget {
  const _AnalyticsPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    final metrics = provider.dashboard;
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _PageHeader(
            eyebrow: 'ML INSIGHTS & REVENUE',
            title: 'Analytics',
            subtitle: 'Real-time performance and dynamic pricing intelligence',
            icon: Icons.insights_rounded,
          ),
          const SizedBox(height: 18),
          const _SectionTitle('REVENUE & UTILIZATION METRICS'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _MetricCard(
                label: 'GROSS REVENUE',
                value: _rupees(metrics['total_earnings']),
                icon: Icons.currency_rupee_rounded,
                color: AppColors.primary,
              ),
              _MetricCard(
                label: 'CHARGING TIME',
                value: _minutes(metrics['active_minutes']),
                icon: Icons.timer_outlined,
                color: AppColors.secondary,
              ),
              _MetricCard(
                label: 'FLEET UTILIZATION',
                value:
                    '${_number(provider.displayedActiveChargerCount)}/${_number(provider.displayedChargerCount)} Active',
                icon: Icons.ev_station_rounded,
                color: AppColors.success,
              ),
              _MetricCard(
                label: 'AVG RATING',
                value: metrics['average_rating'] != null
                    ? '${metrics['average_rating']} ★'
                    : 'No ratings',
                icon: Icons.star_rounded,
                color: AppColors.marigold,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('DYNAMIC PRICING INTELLIGENCE'),
          const SizedBox(height: 12),
          if (provider.recommendations.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'No live pricing recommendations yet',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Recommendations appear after VoltEZ has enough live demand and availability signals for your fleet.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ...provider.recommendations.map(_RecommendationCard.new),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    final business = provider.business ?? const <String, dynamic>{};
    final name = business['name']?.toString().trim();
    final address = business['address_text']?.toString();
    final category = business['category']?.toString() ?? 'EV Host Partner';
    final verification =
        business['verification_status']?.toString() ?? 'pending';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surface,
                AppColors.primary.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name?.isNotEmpty == true ? name! : 'Your Business',
                          style: AppTypography.displaySmall.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          category.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ActionChip(
                    avatar: Icon(
                      verification == 'verified'
                          ? Icons.verified_rounded
                          : Icons.pending_actions_rounded,
                      color: verification == 'verified'
                          ? AppColors.success
                          : AppColors.marigold,
                      size: 16,
                    ),
                    label: Text(
                      verification.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: verification == 'verified'
                            ? AppColors.success
                            : AppColors.marigold,
                      ),
                    ),
                    onPressed: () {
                      final id = business['id']?.toString();
                      if (id != null) _showBusinessKycDialog(context, id);
                    },
                  ),
                ],
              ),
              if (address != null && address.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: AppTypography.bodyMedium.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('BUSINESS SETTINGS & COMPLIANCE'),
        const SizedBox(height: 10),
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.primary,
            ),
            title: const Text('Host KYC & Verification'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              final id = business['id']?.toString();
              if (id != null) _showBusinessKycDialog(context, id);
            },
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.success,
            ),
            title: const Text('Bank Accounts & Daily Payouts'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Payout setup will be enabled after host KYC is verified.',
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(
              Icons.access_time_rounded,
              color: AppColors.secondary,
            ),
            title: const Text('Operating Hours & Access'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Use a charger’s menu to configure its availability.',
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(
              Icons.refresh_rounded,
              color: AppColors.primary,
            ),
            title: const Text('Refresh Live Fleet Data'),
            onTap: provider.load,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ),
      ],
    );
  }
}

class _ChargerList extends StatelessWidget {
  const _ChargerList(this.chargers, {this.showControls = false});
  final List<Map<String, dynamic>> chargers;
  final bool showControls;

  @override
  Widget build(BuildContext context) {
    if (chargers.isEmpty) {
      return const _EmptyState(
        icon: Icons.ev_station_outlined,
        title: 'No chargers registered',
        message: 'Register a real charger to make it discoverable to drivers.',
      );
    }
    final provider = context.read<BusinessProvider>();
    return Column(
      children: chargers.map((charger) {
        final name = charger['name']?.toString() ?? 'Unnamed charger';
        final status = charger['status']?.toString() ?? 'unknown';
        final power = _number(charger['power_kw']);
        final price = _rupees(charger['price_per_kwh']);
        final ports = (charger['ports'] as List<dynamic>? ?? const []).length;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(status).withValues(alpha: 0.15),
              child: Icon(
                Icons.ev_station_rounded,
                color: _statusColor(status),
              ),
            ),
            title: Text(name, style: AppTypography.headlineSmall),
            subtitle: Text(
              '$power kW • $ports port${ports == 1 ? '' : 's'} • $price/kWh',
            ),
            trailing: showControls
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'add_port') {
                        _showAddPort(context, charger);
                      } else if (value == 'availability') {
                        _showAvailability(context, charger);
                      } else if (value == 'tariff') {
                        _showEditTariff(context, charger);
                      } else {
                        provider.setChargerStatus(
                          charger['id'].toString(),
                          value,
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'add_port',
                        child: Text('Add connector port'),
                      ),
                      PopupMenuItem(
                        value: 'availability',
                        child: Text('Set availability'),
                      ),
                      PopupMenuItem(
                        value: 'tariff',
                        child: Text('Update base tariff'),
                      ),
                      PopupMenuItem(
                        value: 'available',
                        child: Text('Available'),
                      ),
                      PopupMenuItem(
                        value: 'unavailable',
                        child: Text('Unavailable'),
                      ),
                      PopupMenuItem(
                        value: 'maintenance',
                        child: Text('Maintenance'),
                      ),
                      PopupMenuItem(value: 'offline', child: Text('Offline')),
                    ],
                  )
                : Chip(label: Text(status.toUpperCase())),
          ),
        );
      }).toList(),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList(this.bookings, {required this.allowCancel});
  final List<Map<String, dynamic>> bookings;
  final bool allowCancel;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const _EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No bookings yet',
        message: 'Driver reservations will appear here when they are made.',
      );
    }
    final provider = context.read<BusinessProvider>();
    return Column(
      children: bookings.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final booking = entry.value;
        final start = DateTime.tryParse(
          booking['start_at']?.toString() ?? '',
        )?.toLocal();
        final status = booking['status']?.toString() ?? 'unknown';
        final isConfirmed =
            status.toLowerCase() == 'confirmed' ||
            status.toLowerCase() == 'checked_in';
        final isCheckedInOrCharging =
            status.toLowerCase() == 'checked_in' ||
            status.toLowerCase() == 'charging';
        final cancellable = const {
          'pending',
          'held',
          'confirmed',
        }.contains(status.toLowerCase());

        final userName = booking['user_name']?.toString() ??
            booking['customer_name']?.toString() ??
            'Driver #$index';
        final userPhone = booking['user_phone']?.toString() ??
            booking['phone']?.toString() ??
            booking['customer_phone']?.toString() ??
            '+91 98765 43210';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: #index badge, Charger name, status chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$index',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        booking['charger_name']?.toString() ?? 'Fleet Charger',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isCheckedInOrCharging
                            ? AppColors.success.withValues(alpha: 0.2)
                            : isConfirmed
                                ? AppColors.secondary.withValues(alpha: 0.2)
                                : AppColors.marigold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCheckedInOrCharging
                              ? AppColors.success
                              : isConfirmed
                                  ? AppColors.secondary
                                  : AppColors.marigold,
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: isCheckedInOrCharging
                              ? AppColors.success
                              : isConfirmed
                                  ? AppColors.secondary
                                  : AppColors.marigold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Customer Info: Name & Contact Number
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_rounded,
                                  size: 12,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  userPhone,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Booking details: Time & Connector
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      start == null ? 'Time pending' : _dateTime(start),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.ev_station_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      booking['connector_type']?.toString() ?? 'Standard',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                // Actions: Verify OTP button + Cancel button
                if (allowCancel) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (cancellable)
                        IconButton(
                          tooltip: 'Cancel booking',
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: AppColors.error,
                            size: 20,
                          ),
                          onPressed: () =>
                              provider.cancelBooking(booking['id'].toString()),
                        )
                      else
                        const SizedBox.shrink(),

                      if (isConfirmed || cancellable)
                        ElevatedButton.icon(
                          onPressed: () => _showVerifyCashCode(
                            context,
                            provider,
                            booking,
                            userName: userName,
                            userPhone: userPhone,
                          ),
                          icon: const Icon(Icons.verified_user_rounded, size: 16),
                          label: const Text('VERIFY'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        )
                      else if (isCheckedInOrCharging)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AppColors.success,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'VERIFIED',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showVerifyCashCode(
    BuildContext context,
    BusinessProvider provider,
    Map<String, dynamic> booking, {
    required String userName,
    required String userPhone,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.verified_user_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Verify Check-in OTP'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer: $userName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Phone: $userPhone',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter the 6-digit check-in OTP given by the driver to verify and start charging.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Check-in OTP Code',
                hintText: 'e.g. 482910',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final success = await provider.verifyCashCode(
                booking['id'].toString(),
                controller.text.trim(),
              );
              if (!context.mounted) return;
              if (success) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('OTP verified! Charging started for $userName.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.errorMessage ?? 'OTP Verification failed'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('VERIFY & START'),
          ),
        ],
      ),
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList(this.reviews);
  final List<Map<String, dynamic>> reviews;
  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const _EmptyState(
        icon: Icons.rate_review_outlined,
        title: 'No reviews yet',
        message: 'Completed session feedback will be shown here.',
      );
    }
    return Column(
      children: reviews.map((review) {
        final rating = (review['rating'] as num?)?.toDouble() ?? 0;
        final comment = review['comment']?.toString().trim();
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.star_rounded, color: AppColors.marigold),
            title: Text('${rating.toStringAsFixed(1)} / 5'),
            subtitle: Text(
              comment?.isNotEmpty == true ? comment! : 'No written feedback',
            ),
          ),
        );
      }).toList(),
    );
  }
}

String _formatReasonCode(String? raw, Map<String, dynamic> data) {
  if (raw == null || raw.trim().isEmpty) return 'Based on live demand signals';
  final code = raw.trim();
  final discountPct = (data['suggested_discount_pct'] as num?)?.toInt() ?? 10;
  final demand = (data['expected_demand'] as num?)?.toDouble() ?? 0.5;
  final demandText = demand > 0.8 ? 'high' : (demand < 0.3 ? 'low' : 'moderate');
  
  switch (code.toUpperCase()) {
    case 'BUSINESS_OFF_PEAK':
    case 'LOW_OCCUPANCY_DISCOUNT':
      return 'Prices can be dropped by $discountPct% due to $demandText demand';
    case 'HIGH_DEMAND_LOW_SUPPLY':
      return 'High demand ($demandText) & peak charger utilization';
    case 'SURGE_PRICING':
      return 'Surge demand pricing adjustment';
    case 'EV_NIGHT_TARIFF':
      return 'Overnight charging tariff optimization';
    case 'COMPETITOR_UNDERCUT_RISK':
      return 'Competitive price positioning';
    default:
      if (code.contains('_') || code == code.toUpperCase()) {
        return code
            .split('_')
            .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
            .join(' ');
      }
      return code;
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard(this.data);
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0;
    final percent = confidence <= 1 ? confidence * 100 : confidence;
    final action = data['recommended_action']?.toString() ?? 'Recommendation';
    final rawReason = data['reason_code']?.toString();
    final cleanReason = _formatReasonCode(rawReason, data);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cleanReason,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${percent.round()}% match',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Text(value, style: AppTypography.headlineMedium),
          Text(label, style: AppTypography.labelSmall),
        ],
      ),
    ),
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onIconTap,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onIconTap;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(title, style: AppTypography.displaySmall),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTypography.bodySmall),
          ],
        ),
      ),
      onIconTap == null
          ? CircleAvatar(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              child: Icon(icon),
            )
          : IconButton.filled(
              onPressed: onIconTap,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              icon: Icon(icon),
            ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: AppTypography.labelMedium.copyWith(
      letterSpacing: 1.1,
      color: AppColors.secondary,
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTypography.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.error.withValues(alpha: 0.08),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    ),
  );
}

class _BusinessOnboarding extends StatefulWidget {
  const _BusinessOnboarding({required this.onCreated});
  final Future<void> Function() onCreated;
  @override
  State<_BusinessOnboarding> createState() => _BusinessOnboardingState();
}

class _BusinessOnboardingState extends State<_BusinessOnboarding> {
  final _name = TextEditingController();
  final _category = TextEditingController(text: 'charging_host');
  final _address = TextEditingController();
  Timer? _addressSearchTimer;
  var _addressSearchToken = 0;
  var _addressSearching = false;
  var _submitting = false;
  List<_AddressSuggestion> _addressSuggestions = const [];
  double? _selectedLatitude;
  double? _selectedLongitude;
  @override
  void dispose() {
    _addressSearchTimer?.cancel();
    _name.dispose();
    _category.dispose();
    _address.dispose();
    super.dispose();
  }

  void _searchAddress(String value) {
    _addressSearchTimer?.cancel();
    final token = ++_addressSearchToken;
    setState(() {
      _selectedLatitude = null;
      _selectedLongitude = null;
      _addressSuggestions = const [];
      _addressSearching = value.trim().length >= 3;
    });
    if (value.trim().length < 3) return;
    _addressSearchTimer = Timer(const Duration(milliseconds: 350), () async {
      final suggestions = await _searchAddressSuggestions(
        value.trim(),
        api: context.read<ApiService>(),
      );
      if (!mounted || token != _addressSearchToken) return;
      setState(() {
        _addressSuggestions = suggestions;
        _addressSearching = false;
      });
    });
  }

  Future<void> _useCurrentLocation() async {
    _addressSearchTimer?.cancel();
    _addressSearchToken++;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission was denied.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      setState(() {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
        _address.text = 'Current device location';
        _addressSuggestions = const [];
        _addressSearching = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read device location: $error')),
      );
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_name.text.trim().isEmpty ||
        _selectedLatitude == null ||
        _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a business name and select a verified address.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    final ok = await context.read<BusinessProvider>().createBusiness(
      name: _name.text.trim(),
      category: _category.text.trim(),
      address: _address.text.trim(),
      latitude: _selectedLatitude!,
      longitude: _selectedLongitude!,
    );
    if (!mounted) return;
    if (ok) {
      await widget.onCreated();
    } else {
      final error =
          context.read<BusinessProvider>().errorMessage ??
          'Business registration failed. Check the server connection and try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.business_rounded,
            size: 56,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          Text('Register your business', style: AppTypography.displaySmall),
          const SizedBox(height: 6),
          const Text(
            'We need the real location so drivers can discover your chargers accurately.',
          ),
          const SizedBox(height: 20),
          _input(_name, 'Business name'),
          _input(_category, 'Category'),
          TextField(
            controller: _address,
            onChanged: _searchAddress,
            decoration: InputDecoration(
              labelText: 'Search business address',
              hintText: 'Search a landmark, street, or business',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Use current location',
                icon: const Icon(Icons.my_location_rounded),
                onPressed: _useCurrentLocation,
              ),
            ),
          ),
          if (_addressSearching)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_addressSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: _addressSuggestions
                    .map(
                      (suggestion) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(
                          suggestion.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => setState(() {
                          _addressSearchTimer?.cancel();
                          _addressSearchToken++;
                          _selectedLatitude = suggestion.latitude;
                          _selectedLongitude = suggestion.longitude;
                          _address.text = suggestion.label;
                          _addressSuggestions = const [];
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (_selectedLatitude != null)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                'Location selected. Coordinates will be saved automatically.',
                style: TextStyle(fontSize: 12, color: AppColors.success),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'CREATING…' : 'CREATE BUSINESS'),
          ),
        ],
      ),
    ),
  );
  Widget _input(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: keyboard == null
          ? null
          : [FilteringTextInputFormatter.allow(RegExp(r'[-.0-9]'))],
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class _AddressSuggestion {
  const _AddressSuggestion({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

Future<List<_AddressSuggestion>> _searchAddressSuggestions(
  String query, {
  ApiService? api,
}) async {
  // Use the backend's ranked, India-constrained geocoder first so every
  // address field (business onboarding and charger registration) behaves the
  // same way across Android/iOS. The OS geocoder is an offline fallback.
  try {
    final response = await (api ?? ApiService()).searchLocations(query);
    final data = response.data;
    if (data is List && data.isNotEmpty) {
      return data
          .whereType<Map>()
          .map(
            (item) => _AddressSuggestion(
              label: AddressFormatter.cleanAddressString(
                item['display_name']?.toString() ?? query,
              ),
              latitude: (item['latitude'] as num).toDouble(),
              longitude: (item['longitude'] as num).toDouble(),
            ),
          )
          .toList();
    }
  } catch (_) {
    // Fall through to the native geocoder when the API/provider is offline.
  }
  try {
    final locations = await locationFromAddress(query);
    final suggestions = <_AddressSuggestion>[];
    for (final location in locations.take(5)) {
      var label = query;
      try {
        final placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        if (placemarks.isNotEmpty) {
          label = AddressFormatter.formatPlacemark(placemarks.first, query);
        }
      } catch (_) {
        // Coordinates remain usable even when reverse labelling is unavailable.
      }
      suggestions.add(
        _AddressSuggestion(
          label: label,
          latitude: location.latitude,
          longitude: location.longitude,
        ),
      );
    }
    return suggestions;
  } catch (_) {
    return const [];
  }
}

Future<void> _showAddCharger(BuildContext context) async {
  final biz = context.read<BusinessProvider>().business;
  final defaultAddress = biz?['address_text']?.toString() ?? '';

  final name = TextEditingController();
  final power = TextEditingController();
  final price = TextEditingController(text: '15');
  final portNumber = TextEditingController(text: '1');
  final portPower = TextEditingController(text: '22');
  final location = TextEditingController(text: defaultAddress);
  Timer? searchTimer;
  var searchToken = 0;
  var chargerType = 'DC';
  var connectorTypeId = 1;
  var accessType = 'public';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      var suggestions = <_AddressSuggestion>[];
      var searching = false;
      var saving = false;
      // A charger must be tied to an explicitly confirmed place. The
      // business address is shown as a convenience, but it is not silently
      // submitted as the charger's coordinates if the owner edits the field.
      double? selectedLatitude;
      double? selectedLongitude;

      Future<void> search(
        String query,
        void Function(void Function()) setState,
      ) async {
        searchTimer?.cancel();
        final token = ++searchToken;
        if (query.trim().length < 3) {
          setState(() {
            suggestions = [];
            searching = false;
          });
          return;
        }
        searchTimer = Timer(const Duration(milliseconds: 350), () async {
          if (!dialogContext.mounted) return;
          setState(() => searching = true);
          final results = await _searchAddressSuggestions(
            query.trim(),
            api: context.read<ApiService>(),
          );
          if (!dialogContext.mounted || token != searchToken) return;
          setState(() {
            suggestions = results;
            searching = false;
          });
        });
      }

      Future<void> useCurrentLocation(
        void Function(void Function()) setState,
      ) async {
        searchTimer?.cancel();
        searchToken++;
        try {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            throw StateError('Location permission was denied.');
          }
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          if (!dialogContext.mounted) return;
          selectedLatitude = position.latitude;
          selectedLongitude = position.longitude;
          location.text = 'Current device location';
          setState(() => suggestions = []);
        } catch (error) {
          if (dialogContext.mounted) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(content: Text('Could not read device location: $error')),
            );
          }
        }
      }

      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.ev_station_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Register charger',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.68,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'QUICK EV PRESETS',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          label: const Text(
                            '7.4kW Type 2 AC',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            setState(() {
                              name.text = 'Type 2 AC Charger';
                              chargerType = 'AC';
                              power.text = '7.4';
                              portPower.text = '7.4';
                              price.text = '12';
                              connectorTypeId = 2;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: AppColors.secondary,
                          ),
                          label: const Text(
                            '22kW Fast AC',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            setState(() {
                              name.text = '22kW Fast AC Station';
                              chargerType = 'AC';
                              power.text = '22';
                              portPower.text = '22';
                              price.text = '14';
                              connectorTypeId = 2;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(
                            Icons.flash_on_rounded,
                            size: 14,
                            color: AppColors.marigold,
                          ),
                          label: const Text(
                            '30kW CCS2 DC',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            setState(() {
                              name.text = '30kW DC Fast Charger';
                              chargerType = 'DC';
                              power.text = '30';
                              portPower.text = '30';
                              price.text = '18';
                              connectorTypeId = 1;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(
                            Icons.electric_bolt_rounded,
                            size: 14,
                            color: AppColors.success,
                          ),
                          label: const Text(
                            '60kW Superfast DC',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            setState(() {
                              name.text = '60kW High-Speed DC';
                              chargerType = 'DC';
                              power.text = '60';
                              portPower.text = '60';
                              price.text = '21';
                              connectorTypeId = 1;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _dialogInput(name, 'Name'),

                  _dialogDropdown<String>(
                    value: chargerType,
                    labelText: 'Charging type',
                    items: const [
                      DropdownMenuItem(value: 'AC', child: Text('AC charging')),
                      DropdownMenuItem(
                        value: 'DC',
                        child: Text('DC fast charging'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => chargerType = value);
                    },
                  ),
                  _dialogInput(
                    power,
                    'Station power (kW)',
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _dialogInput(
                    portPower,
                    'First port maximum power (kW)',
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _dialogInput(
                    portNumber,
                    'Port number',
                    keyboard: TextInputType.number,
                  ),
                  _dialogDropdown<int>(
                    value: connectorTypeId,
                    labelText: 'Connector standard',
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('CCS2')),
                      DropdownMenuItem(value: 2, child: Text('Type 2')),
                      DropdownMenuItem(value: 3, child: Text('CHAdeMO')),
                      DropdownMenuItem(value: 4, child: Text('Bharat AC-001')),
                      DropdownMenuItem(value: 5, child: Text('Bharat DC-001')),
                      DropdownMenuItem(value: 6, child: Text('Type 1')),
                      DropdownMenuItem(value: 7, child: Text('GB/T')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => connectorTypeId = value);
                      }
                    },
                  ),
                  _dialogDropdown<String>(
                    value: accessType,
                    labelText: 'Access',
                    items: const [
                      DropdownMenuItem(value: 'public', child: Text('Public')),
                      DropdownMenuItem(
                        value: 'controlled',
                        child: Text('Controlled access'),
                      ),
                      DropdownMenuItem(
                        value: 'customer_only',
                        child: Text('Customers only'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => accessType = value);
                    },
                  ),
                  _dialogInput(
                    price,
                    'Base price per kWh (INR)',
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 2, bottom: 14),
                    child: Text(
                      'VoltEZ applies a bounded peak/off-peak multiplier using live demand and availability signals.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextField(
                      controller: location,
                      onChanged: (value) {
                        selectedLatitude = null;
                        selectedLongitude = null;
                        search(value, setState);
                      },
                      decoration: InputDecoration(
                        labelText: 'Search charger address',
                        hintText: 'Search a landmark, street, or business',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Use current location',
                          icon: const Icon(Icons.my_location_rounded),
                          onPressed: () => useCurrentLocation(setState),
                        ),
                      ),
                    ),
                  ),
                  if (searching) const LinearProgressIndicator(minHeight: 2),
                  if (suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: suggestions
                            .map(
                              (suggestion) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on_outlined),
                                title: Text(
                                  suggestion.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  searchTimer?.cancel();
                                  searchToken++;
                                  selectedLatitude = suggestion.latitude;
                                  selectedLongitude = suggestion.longitude;
                                  location.text = suggestion.label;
                                  setState(() => suggestions = []);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (selectedLatitude != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Location selected. Coordinates will be saved automatically.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final p = double.tryParse(power.text.trim());
                      final pr = double.tryParse(price.text.trim());
                      final pp = double.tryParse(portPower.text.trim());
                      final pn = int.tryParse(portNumber.text.trim());
                      if (name.text.trim().isEmpty ||
                          p == null ||
                          p <= 0 ||
                          pp == null ||
                          pp <= 0 ||
                          pn == null ||
                          pn <= 0 ||
                          pr == null ||
                          pr <= 0) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enter a name, positive power, and base tariff.',
                            ),
                          ),
                        );
                        return;
                      }
                      if (selectedLatitude == null ||
                          selectedLongitude == null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Select a location suggestion or use current location before saving.',
                            ),
                          ),
                        );
                        return;
                      }
                      final chargerLatitude = selectedLatitude!;
                      final chargerLongitude = selectedLongitude!;
                      final businessProvider = context.read<BusinessProvider>();

                      if (!dialogContext.mounted) return;
                      setState(() => saving = true);
                      final ok = await businessProvider.createCharger(
                        name: name.text.trim(),
                        chargerType: chargerType,
                        powerKw: p,
                        pricePerKwh: pr,
                        latitude: chargerLatitude,
                        longitude: chargerLongitude,
                        addressText: location.text.trim().isNotEmpty
                            ? location.text.trim()
                            : defaultAddress,
                        connectorTypeId: connectorTypeId,
                        portNumber: pn,
                        portMaxPowerKw: pp,
                        accessType: accessType,
                      );

                      if (!dialogContext.mounted) return;
                      if (ok) {
                        Navigator.pop(dialogContext);
                      } else {
                        final error =
                            context.read<BusinessProvider>().errorMessage ??
                            'Charger could not be registered. Check your session and try again.';
                        ScaffoldMessenger.of(
                          dialogContext,
                        ).showSnackBar(SnackBar(content: Text(error)));
                        setState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'SAVING…' : 'SAVE'),
            ),
          ],
        ),
      );
    },
  );
  searchTimer?.cancel();
  name.dispose();
  power.dispose();
  price.dispose();
  portNumber.dispose();
  portPower.dispose();
  location.dispose();
}

Future<void> _showAddPort(
  BuildContext context,
  Map<String, dynamic> charger,
) async {
  final portNumber = TextEditingController();
  final power = TextEditingController();
  var connectorId = 1;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Add port to ${charger['name'] ?? 'charger'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogDropdown<int>(
                value: connectorId,
                labelText: 'Connector',
                items: const [
                  DropdownMenuItem(value: 1, child: Text('CCS2')),
                  DropdownMenuItem(value: 2, child: Text('Type 2')),
                  DropdownMenuItem(value: 3, child: Text('CHAdeMO')),
                  DropdownMenuItem(value: 4, child: Text('Bharat AC-001')),
                  DropdownMenuItem(value: 5, child: Text('Bharat DC-001')),
                  DropdownMenuItem(value: 6, child: Text('Type 1')),
                  DropdownMenuItem(value: 7, child: Text('GB/T')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => connectorId = value);
                },
              ),
              _dialogInput(
                portNumber,
                'Port number',
                keyboard: TextInputType.number,
              ),
              _dialogInput(
                power,
                'Maximum power (kW)',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 6),
              const Text(
                'After adding the port, use “Set availability” to publish host-approved time windows.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              final number = int.tryParse(portNumber.text.trim());
              final maxPower = double.tryParse(power.text.trim());
              if (number == null ||
                  number <= 0 ||
                  maxPower == null ||
                  maxPower <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid port number and power.'),
                  ),
                );
                return;
              }
              final ok = await context.read<BusinessProvider>().createPort(
                chargerId: charger['id'].toString(),
                connectorTypeId: connectorId,
                portNumber: number,
                maxPowerKw: maxPower,
              );
              if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('ADD PORT'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showEditTariff(
  BuildContext context,
  Map<String, dynamic> charger,
) async {
  final price = TextEditingController(
    text: charger['price_per_kwh']?.toString() ?? '',
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Update base tariff · ${charger['name'] ?? ''}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogInput(
              price,
              'Base price per kWh (INR)',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            const Text(
              'This is the owner-controlled base. VoltEZ applies a bounded live multiplier per slot.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () async {
            final value = double.tryParse(price.text.trim());
            if (value == null || value <= 0) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Enter a positive base tariff.')),
              );
              return;
            }
            final ok = await context
                .read<BusinessProvider>()
                .updateChargerTariff(
                  chargerId: charger['id'].toString(),
                  pricePerKwh: value,
                );
            if (!dialogContext.mounted) return;
            if (ok) {
              Navigator.pop(dialogContext);
            } else {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text(
                    context.read<BusinessProvider>().errorMessage ??
                        'Could not update tariff.',
                  ),
                ),
              );
            }
          },
          child: const Text('SAVE TARIFF'),
        ),
      ],
    ),
  );
}

Future<void> _showAvailability(
  BuildContext context,
  Map<String, dynamic> charger,
) async {
  final rawPorts = (charger['ports'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((port) => Map<String, dynamic>.from(port))
      .toList();
  if (rawPorts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add a connector port before publishing availability.'),
      ),
    );
    return;
  }
  final start = TextEditingController(text: '08:00');
  final end = TextEditingController(text: '22:00');
  var day = DateTime.now().weekday - 1;
  var portId = rawPorts.first['id'].toString();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Publish availability'),
            if ((charger['name'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                charger['name'].toString(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              _dialogDropdown<String>(
                value: portId,
                labelText: 'Port',
                items: [
                  for (final port in rawPorts)
                    DropdownMenuItem(
                      value: port['id'].toString(),
                      child: Text('Port ${port['port_number'] ?? ''}'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => portId = value);
                },
              ),
              _dialogDropdown<int>(
                value: day,
                labelText: 'Day',
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Monday')),
                  DropdownMenuItem(value: 1, child: Text('Tuesday')),
                  DropdownMenuItem(value: 2, child: Text('Wednesday')),
                  DropdownMenuItem(value: 3, child: Text('Thursday')),
                  DropdownMenuItem(value: 4, child: Text('Friday')),
                  DropdownMenuItem(value: 5, child: Text('Saturday')),
                  DropdownMenuItem(value: 6, child: Text('Sunday')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => day = value);
                },
              ),
              _dialogInput(start, 'Start time (HH:MM)'),
              _dialogInput(end, 'End time (HH:MM)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              final validTime = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
              if (!validTime.hasMatch(start.text.trim()) ||
                  !validTime.hasMatch(end.text.trim()) ||
                  start.text.trim().compareTo(end.text.trim()) >= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Use valid times and ensure end is after start.',
                    ),
                  ),
                );
                return;
              }
              final ok = await context
                  .read<BusinessProvider>()
                  .createAvailability(
                    portId: portId,
                    dayOfWeek: day,
                    startTime: start.text.trim(),
                    endTime: end.text.trim(),
                  );
              if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('PUBLISH'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showBusinessKycDialog(
  BuildContext context,
  String businessId,
) async {
  final gstin = TextEditingController();
  final pan = TextEditingController();
  final meter = TextEditingController();
  final upi = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.verified_user_rounded, color: AppColors.primary),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Host KYC Verification',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),

      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.58,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Submit verified business credentials to receive automated driver payouts and unlock 24/7 public listing.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _dialogInput(gstin, 'GSTIN (e.g. 27AAAAA0000A1Z5)'),
              _dialogInput(pan, 'Business PAN (e.g. AAAAA0000A)'),
              _dialogInput(meter, 'Electricity Consumer / Meter ID'),
              _dialogInput(upi, 'Payout UPI ID'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () async {
            if (gstin.text.trim().isEmpty && pan.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter at least GSTIN or PAN.'),
                ),
              );
              return;
            }
            try {
              final ok = await context.read<BusinessProvider>().submitKyc(
                businessId: businessId,
                gstin: gstin.text.trim().isNotEmpty ? gstin.text.trim() : null,
                panNumber: pan.text.trim().isNotEmpty ? pan.text.trim() : null,
                electricityMeterId: meter.text.trim().isNotEmpty
                    ? meter.text.trim()
                    : null,
                payoutUpiId: upi.text.trim().isNotEmpty
                    ? upi.text.trim()
                    : null,
              );
              if (dialogContext.mounted && ok) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Host KYC submitted. Verification status: PENDING REVIEW',
                    ),
                  ),
                );
              } else if (dialogContext.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('KYC submission failed. Please retry.'),
                  ),
                );
              }
            } catch (e) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('KYC submission error: $e')),
                );
              }
            }
          },
          child: const Text('VERIFY & SUBMIT'),
        ),
      ],
    ),
  );
}

Widget _dialogInput(
  TextEditingController c,
  String label, {
  TextInputType keyboard = TextInputType.text,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 18),
  child: TextField(
    controller: c,
    decoration: InputDecoration(labelText: label),
    keyboardType: keyboard,
  ),
);

Widget _dialogDropdown<T>({
  required T value,
  required String labelText,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 18),
  child: DropdownButtonFormField<T>(
    initialValue: value,
    decoration: InputDecoration(labelText: labelText),
    items: items,
    onChanged: onChanged,
  ),
);
List<Map<String, dynamic>> _listOfMaps(dynamic value) =>
    (value as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
String _number(dynamic value) => value is num
    ? (value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1))
    : '0';
String _rupees(dynamic value) => '₹${_number(value)}';
String _minutes(dynamic value) {
  final mins = (value as num?)?.toDouble() ?? 0;
  return mins >= 60
      ? '${(mins / 60).toStringAsFixed(1)} h'
      : '${mins.toStringAsFixed(0)} m';
}

String _dateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

Future<void> _showBusinessNotifications(BuildContext context) async {
  List<Map<String, dynamic>> notifications = const [];
  String? error;
  try {
    final response = await context.read<ApiService>().getNotifications();
    final data = response.data;
    if (data is List) {
      notifications = data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
  } catch (_) {
    error = 'Could not load notifications right now.';
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Notifications'),
      content: SizedBox(
        width: 360,
        child: error != null
            ? Text(error)
            : notifications.isEmpty
            ? const Text('No notifications yet.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: notifications
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.notifications_outlined,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            item['title']?.toString() ?? 'VoltEZ alert',
                          ),
                          subtitle: Text(item['message']?.toString() ?? ''),
                          isThreeLine: true,
                          onTap: () {
                            final id = item['id']?.toString();
                            if (id != null) {
                              context.read<ApiService>().markNotificationRead(
                                id,
                              );
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('CLOSE'),
        ),
      ],
    ),
  );
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'available':
      return AppColors.success;
    case 'maintenance':
      return AppColors.marigold;
    case 'unavailable':
      return AppColors.coral;
    default:
      return AppColors.textMuted;
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onChanged});
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onChanged,
    destinations: const [
      NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
      NavigationDestination(
        icon: Icon(Icons.ev_station_rounded),
        label: 'Chargers',
      ),
      NavigationDestination(
        icon: Icon(Icons.calendar_today_rounded),
        label: 'Bookings',
      ),
      NavigationDestination(
        icon: Icon(Icons.insights_rounded),
        label: 'Analytics',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        label: 'Profile',
      ),
    ],
  );
}
