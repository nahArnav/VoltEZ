import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/charger_discovery_provider.dart';
import '../../../core/providers/route_planner_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/network/api_service.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/models/models.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _selectedNav = 0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final discovery = context.read<ChargerDiscoveryProvider>();
      if (discovery.allChargers.isEmpty && !discovery.chargersLoading) {
        discovery.init();
      }
      context.read<RoutePlannerProvider>().loadVehicles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _selectedNav == 0
            ? _buildHomeTab()
            : _selectedNav == 2
            ? _buildChargersTab()
            : _selectedNav == 3
            ? _buildBookingsTab()
            : _selectedNav == 4
            ? _buildProfileTab()
            : _buildPlaceholderTab(),
      ),
      bottomNavigationBar: AppBottomNavBar(
        items: AppBottomNavBar.driverItems,
        selectedIndex: _selectedNav,
        onChanged: (index) {
          if (index == 1) {
            context.go('/driver/map');
            return;
          }
          if (index == 3) {
            context.go('/driver/history');
            return;
          }
          setState(() => _selectedNav = index);
        },
      ),
    );
  }

  // ─── HOME TAB ───
  Widget _buildHomeTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeader(),
              const SizedBox(height: 16),

              // Active session banner
              Consumer<SessionProvider>(
                builder: (context, session, _) {
                  if (session.phase != SessionPhase.charging &&
                      session.phase != SessionPhase.checkedIn) {
                    return const SizedBox.shrink();
                  }
                  return _buildActiveSessionBanner(session);
                },
              ),

              const SizedBox(height: 8),
              _buildBatteryCard(),
              const SizedBox(height: 24),
              _buildSearchBar(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 28),
              _buildSectionHeader('NEARBY CHARGERS', 'See all'),
              const SizedBox(height: 14),
              _buildNearbyChargers(),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  // ─── Active Session Banner ───
  Widget _buildActiveSessionBanner(SessionProvider session) {
    final data = session.sessionData;
    final soc = data?.batteryPercent ?? 0;
    final isCharging = session.phase == SessionPhase.charging;

    return GestureDetector(
      onTap: () => context.go('/driver/session'),
      child: GlassCard(
        accentColor: AppColors.primary,
        padding: const EdgeInsets.all(16),
        borderRadius: 18,
        child: Row(
          children: [
            // Pulsing indicator
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCharging ? Icons.bolt_rounded : Icons.ev_station_rounded,
                color: AppColors.onPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCharging ? 'CHARGING NOW' : 'CHECKED IN',
                    style: TextStyle(
                      color: AppColors.onPrimary.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data?.chargerName ?? 'Charger',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                if (isCharging)
                  Text(
                    '${soc.round()}%',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.onPrimary.withValues(alpha: 0.7),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VOLTEZ / DRIVER',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text('${_greeting()},', style: AppTypography.bodyMedium),
              const SizedBox(height: 2),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final name = auth.user?.name ?? 'Driver';
                  return Text(name, style: AppTypography.displaySmall);
                },
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.textOnPrimary,
            size: 23,
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryCard() {
    return Consumer<RoutePlannerProvider>(
      builder: (context, planner, _) {
        final vehicle = planner.selectedVehicle;
        if (vehicle == null) {
          return const _HomeInfoCard(
            icon: Icons.directions_car_outlined,
            title: 'Add your EV details',
            message:
                'Save a car, bike or auto profile to unlock accurate range and charger compatibility.',
          );
        }
        return GlassCard(
          accentColor: AppColors.primary,
          padding: const EdgeInsets.all(22),
          borderRadius: 22,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BATTERY STATUS',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                  const Text(
                    '—',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Live battery percentage is available during an active session.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onPrimary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _batteryMetric(
                    Icons.bolt_rounded,
                    '${vehicle.batteryKwh.toStringAsFixed(1)} kWh',
                    'Capacity',
                    AppColors.primary,
                  ),
                  _batteryMetric(
                    Icons.route_rounded,
                    vehicle.estimatedRangeKm == null
                        ? '—'
                        : '${vehicle.estimatedRangeKm!.round()} km',
                    'Range',
                    AppColors.primary,
                  ),
                  _batteryMetric(
                    Icons.ev_station_rounded,
                    vehicle.primaryConnector,
                    'Connector',
                    AppColors.secondary,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _batteryMetric(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: AppColors.onPrimary.withValues(alpha: 0.8), size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.onPrimary,
          ),
        ),
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.onPrimary.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => context.go('/driver/map'),
      child: GlassCard(
        accentColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 14,
        blur: 12,
        opacity: 0.55,
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: AppColors.onPrimary.withValues(alpha: 0.7),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search destination or charger...',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onPrimary.withValues(alpha: 0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (
        Icons.route_rounded,
        'Route\nPlanner',
        AppColors.primary,
        '/driver/route-planner',
      ),
      (
        Icons.ev_station_rounded,
        'Find\nCharger',
        AppColors.success,
        '/driver/map',
      ),
      (
        Icons.bolt_rounded,
        'Active\nSession',
        AppColors.secondary,
        '/driver/session',
      ),
      (
        Icons.history_rounded,
        'Booking\nHistory',
        AppColors.warning,
        '/driver/history',
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: actions.map((a) {
        return GestureDetector(
          onTap: () => context.go(a.$4),
          child: Column(
            children: [
              GlassCard(
                accentColor: a.$3,
                padding: const EdgeInsets.all(0),
                borderRadius: 18,
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: Icon(a.$1, color: AppColors.onPrimary, size: 28),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                a.$2,
                textAlign: TextAlign.center,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      children: [
        Text('01', style: AppTypography.sectionNumber),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppColors.border)),
        const SizedBox(width: 10),
        Text(title, style: AppTypography.sectionLabel),
        const Spacer(),
        GestureDetector(
          onTap: () => context.go('/driver/map'),
          child: Text(
            action,
            style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyChargers() {
    return Consumer<ChargerDiscoveryProvider>(
      builder: (context, discovery, _) {
        if (discovery.chargersLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final chargers = discovery.filteredChargers;

        if (chargers.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.ev_station_rounded,
                  color: AppColors.textMuted,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  discovery.chargersError != null
                      ? 'Unable to load chargers'
                      : 'No chargers nearby',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                if (discovery.chargersError != null) ...[
                  const SizedBox(height: 8),
                  Text('Pull down to retry', style: AppTypography.bodySmall),
                ],
              ],
            ),
          );
        }

        return Column(
          children: chargers.take(5).map((charger) {
            final distance = discovery.distanceTo(charger);
            final distanceLabel = distance > 0
                ? '${distance.toStringAsFixed(1)} km away'
                : charger.address ?? '';

            final statusColor = charger.chargerStatus == ChargerStatus.available
                ? AppColors.success
                : charger.chargerStatus == ChargerStatus.busy
                ? AppColors.warning
                : AppColors.textMuted;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChargerCard(
                name: charger.name,
                power: '${charger.powerKw.round()} kW',
                price: '₹${charger.basePrice.round()}/kWh',
                status: charger.chargerStatus,
                address: distanceLabel,
                rating: charger.rating,
                amenities: charger.amenitiesList,
                onTap: () => context.go('/driver/charger/${charger.id}'),
                glass: true,
                accentColor: statusColor,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ─── CHARGERS TAB ───
  Widget _buildChargersTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All Chargers', style: AppTypography.displaySmall),
          const SizedBox(height: 16),
          Consumer<ChargerDiscoveryProvider>(
            builder: (context, discovery, _) {
              return TextField(
                controller: _searchController,
                onChanged: discovery.setSearchQuery,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search chargers...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<ChargerDiscoveryProvider>(
              builder: (context, discovery, _) {
                if (discovery.chargersLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final chargers = discovery.filteredChargers;

                if (chargers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          color: AppColors.textMuted,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No chargers found',
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => discovery.refreshChargers(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: chargers.length,
                    itemBuilder: (context, index) {
                      final charger = chargers[index];
                      final distance = discovery.distanceTo(charger);
                      final distanceLabel = distance > 0
                          ? '${distance.toStringAsFixed(1)} km away'
                          : charger.address ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ChargerCard(
                          name: charger.name,
                          power: '${charger.powerKw.round()} kW',
                          price: '₹${charger.basePrice.round()}/kWh',
                          status: charger.chargerStatus,
                          address: distanceLabel,
                          rating: charger.rating,
                          amenities: charger.amenitiesList,
                          onTap: () =>
                              context.go('/driver/charger/${charger.id}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOOKINGS TAB — redirects to dedicated history screen ───
  // This tab is handled in onChanged (index 3 → history).
  Widget _buildBookingsTab() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  // ─── PROFILE TAB ───
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.secondary.withValues(alpha: 0.2),
                ],
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final name = auth.user?.name ?? 'Driver';
              return Text(name, style: AppTypography.displaySmall);
            },
          ),
          const SizedBox(height: 4),
          const Text('Driver', style: AppTypography.bodyMedium),
          const SizedBox(height: 32),

          // Profile options
          Consumer<RoutePlannerProvider>(
            builder: (context, planner, _) => _profileOption(
              Icons.directions_car_rounded,
              'My Vehicle',
              planner.selectedVehicle?.displayName ?? 'No vehicle saved',
              () => context.go('/driver/onboarding'),
            ),
          ),
          _profileOption(
            Icons.receipt_long_rounded,
            'Booking History',
            'View all bookings and sessions',
            () => context.go('/driver/history'),
          ),
          _profileOption(
            Icons.verified_user_outlined,
            'KYC & Identity Verification',
            'Driving license / Aadhaar status',
            () => _showDriverKycDialog(context),
          ),
          _profileOption(
            Icons.payment_rounded,
            'Payment Methods',
            'UPI, cards or pay-at-charger cash',
            () => _showPaymentMethodsDialog(context),
          ),

          _profileOption(
            Icons.notifications_outlined,
            'Notifications',
            'Manage alerts',
            () => _showNotificationDialog(context),
          ),
          _profileOption(
            Icons.help_outline_rounded,
            'Help & Support',
            'FAQs, contact us',
            () => _showHelpDialog(context),
          ),
          _profileOption(
            Icons.info_outline_rounded,
            'About VoltEZ',
            'Version 1.0.0',
            () => _showAboutDialog(context),
          ),
          const SizedBox(height: 16),
          _profileOption(
            Icons.logout_rounded,
            'Logout',
            'Sign out of your account',
            () async {
              final auth = context.read<AuthProvider>();
              await auth.logout();
              if (!mounted) return;
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _profileOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.headlineSmall),
                    Text(subtitle, style: AppTypography.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab() {
    return const Center(
      child: Text('Coming soon', style: TextStyle(color: AppColors.textMuted)),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

class _HomeInfoCard extends StatelessWidget {
  const _HomeInfoCard({
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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.headlineSmall),
                const SizedBox(height: 4),
                Text(message, style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showDriverKycDialog(BuildContext context) async {
  final docNumber = TextEditingController();
  final rcNumber = TextEditingController();
  String docType = 'driving_license';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.verified_user_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text('Driver KYC Verification')),
          ],
        ),

        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verify your driving credentials to unlock instant slot holds, zero-deposit charging, and higher trust rating.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: docType,
                decoration: const InputDecoration(labelText: 'Document Type'),

                items: const [
                  DropdownMenuItem(
                    value: 'driving_license',
                    child: Text('Driving License (DL)'),
                  ),
                  DropdownMenuItem(
                    value: 'aadhaar',
                    child: Text('Aadhaar / National ID'),
                  ),
                  DropdownMenuItem(value: 'voter_id', child: Text('Voter ID')),
                  DropdownMenuItem(value: 'passport', child: Text('Passport')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => docType = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: docNumber,
                decoration: const InputDecoration(
                  labelText: 'Document / ID Number (e.g. MH1220210001234)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rcNumber,
                decoration: const InputDecoration(
                  labelText: 'Vehicle RC Number (Optional)',
                ),
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
              if (docNumber.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your document ID number.'),
                  ),
                );
                return;
              }
              try {
                await context.read<ApiService>().submitUserKyc({
                  'document_type': docType,
                  'document_number': docNumber.text.trim(),
                  if (rcNumber.text.trim().isNotEmpty)
                    'vehicle_rc_number': rcNumber.text.trim(),
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Driver identity submitted. Verification status: PENDING REVIEW',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Verification error: $e')),
                  );
                }
              }
            },
            child: const Text('VERIFY & SAVE'),
          ),
        ],
      ),
    ),
  );
  docNumber.dispose();
  rcNumber.dispose();
}

Future<void> _showPaymentMethodsDialog(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return;
  var selected = prefs.getString('voltez_default_payment_method') ?? 'upi';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Payment methods'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose the method preselected at checkout. Card and UPI are processed by the configured gateway; cash is settled with the host at arrival.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) setState(() => selected = value);
              },
              child: Column(
                children: [
                  for (final option in const [
                    ('upi', 'UPI', Icons.account_balance_rounded),
                    ('card', 'Card', Icons.credit_card_rounded),
                    ('cash', 'Pay at charger (cash)', Icons.payments_outlined),
                  ])
                    RadioListTile<String>(
                      value: option.$1,
                      title: Text(option.$2),
                      secondary: Icon(option.$3, color: AppColors.primary),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              await prefs.setString('voltez_default_payment_method', selected);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Default payment method saved.'),
                  ),
                );
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showNotificationDialog(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return;
  var enabled = prefs.getBool('voltez_notifications_enabled') ?? true;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Notifications'),
        content: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Booking and session alerts'),
          subtitle: const Text(
            'Stored on this device and used by the app notification layer.',
          ),
          value: enabled,
          onChanged: (value) => setState(() => enabled = value),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              await prefs.setBool('voltez_notifications_enabled', enabled);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('DONE'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showHelpDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Help & support'),
    content: const SingleChildScrollView(
      child: Text(
        'For a booking issue, open Booking History and use the booking status to retry or cancel. For a charger issue, report it from the charger details page. If the API cannot be reached, open Server Configuration on the login screen and use the laptop LAN address or USB runner.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('CLOSE'),
      ),
    ],
  ),
);

Future<void> _showAboutDialog(BuildContext context) async {
  showAboutDialog(
    context: context,
    applicationName: 'VoltEZ',
    applicationVersion: '1.0.0',
    applicationLegalese: 'Smart EV charging marketplace',
    children: const [
      SizedBox(height: 12),
      Text(
        'VoltEZ connects drivers with real, host-approved charging slots and keeps reservations, payments, sessions, and feedback auditable.',
      ),
    ],
  );
}
