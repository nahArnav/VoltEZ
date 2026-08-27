import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/charger_discovery_provider.dart';
import '../../../core/providers/route_planner_provider.dart';
import '../../../core/auth/auth_provider.dart';
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
      context.read<ChargerDiscoveryProvider>().init();
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.success.withValues(alpha: 0.2),
              AppColors.primary.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            // Pulsing indicator
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCharging
                    ? Icons.bolt_rounded
                    : Icons.ev_station_rounded,
                color: AppColors.success,
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
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data?.chargerName ?? 'Charger',
                    style: AppTypography.headlineSmall,
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
                      color: AppColors.success,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.success, size: 16),
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
              Text('VOLTEZ / DRIVER', style: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
              )),
              const SizedBox(height: 8),
              Text('Good evening,', style: AppTypography.bodyMedium),
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
          child: const Icon(Icons.notifications_none_rounded, color: AppColors.textOnPrimary, size: 23),
        ),
      ],
    );
  }

  Widget _buildBatteryCard() {
    return Consumer<RoutePlannerProvider>(
      builder: (context, planner, _) {
        final vehicle = planner.selectedVehicle;
        if (vehicle == null) {
          return _emptyVehicleCard(context, planner.vehiclesError);
        }

        final range = vehicle.estimatedRangeKm;
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withValues(alpha: 0.14), AppColors.card],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VEHICLE PROFILE', style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
              const SizedBox(height: 6),
              Text(vehicle.displayName, style: AppTypography.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Live battery telemetry is not connected. Route estimates use the saved vehicle specification.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _batteryMetric(Icons.bolt_rounded, '${vehicle.batteryKwh.toStringAsFixed(1)} kWh', 'Capacity', AppColors.primary),
                  _batteryMetric(Icons.route_rounded, range == null ? '—' : '${range.round()} km', 'Range', AppColors.primary),
                  _batteryMetric(Icons.ev_station_rounded, vehicle.primaryConnector, 'Connector', AppColors.secondary),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyVehicleCard(BuildContext context, String? error) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car_filled_rounded, color: AppColors.primary, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add your vehicle', style: AppTypography.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  error == null ? 'Save battery and connector details for accurate route recommendations.' : 'Vehicle data could not be loaded. Check your connection and retry.',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(onPressed: () => context.go('/driver/onboarding'), child: const Text('SET UP')),
        ],
      ),
    );
  }

  Widget _batteryMetric(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary)),
        Text(label, style: AppTypography.labelMedium),
      ],
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => context.go('/driver/map'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Text('Search destination or charger...', style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (Icons.route_rounded, 'Route\nPlanner', AppColors.primary, '/driver/route-planner'),
      (Icons.ev_station_rounded, 'Find\nCharger', AppColors.success, '/driver/map'),
      (Icons.bolt_rounded, 'Active\nSession', AppColors.secondary, '/driver/session'),
      (Icons.history_rounded, 'Booking\nHistory', AppColors.warning, '/driver/history'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: actions.map((a) {
        return GestureDetector(
          onTap: () => context.go(a.$4),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: a.$3.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: a.$3.withValues(alpha: 0.25)),
                ),
                child: Icon(a.$1, color: a.$3, size: 28),
              ),
              const SizedBox(height: 8),
              Text(a.$2, textAlign: TextAlign.center, style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              )),
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
        Expanded(
          child: Container(height: 1, color: AppColors.border),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppTypography.sectionLabel),
        const Spacer(),
        GestureDetector(
          onTap: () => context.go('/driver/map'),
          child: Text(action, style: AppTypography.labelMedium.copyWith(
            color: AppColors.primary,
          )),
        ),
      ],
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
          CustomTextField(
            hintText: 'Search chargers...',
            prefixIcon: Icons.search_rounded,
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildNearbyChargers(showAll: true)),
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
            child: const Icon(Icons.person_rounded,
                color: AppColors.primary, size: 44),
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
              planner.selectedVehicle?.displayName ?? 'No vehicle added',
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
            Icons.payment_rounded,
            'Payment Methods',
            'Manage UPI, cards, wallet',
            () {},
          ),
          _profileOption(
            Icons.notifications_outlined,
            'Notifications',
            'Manage alerts',
            () {},
          ),
          _profileOption(
            Icons.help_outline_rounded,
            'Help & Support',
            'FAQs, contact us',
            () {},
          ),
          _profileOption(
            Icons.info_outline_rounded,
            'About VoltEZ',
            'Version 1.0.0',
            () {},
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
      IconData icon, String title, String subtitle, VoidCallback onTap) {
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
              Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.textMuted, size: 16),
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

  Widget _buildNearbyChargers({bool showAll = false}) {
    return Consumer<ChargerDiscoveryProvider>(
      builder: (context, discovery, _) {
        if (discovery.chargersLoading && discovery.allChargers.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        }
        if (discovery.filteredChargers.isEmpty) {
          return Column(
            children: [
              Text(
                discovery.chargersError == null ? 'No chargers found near you.' : 'Chargers could not be loaded.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              if (discovery.chargersError != null) ...[
                const SizedBox(height: 4),
                Text('Check the API connection and try again.', style: AppTypography.bodySmall),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: discovery.chargersLoading ? null : discovery.refreshLocation,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('RETRY'),
              ),
            ],
          );
        }

        final chargers = showAll ? discovery.filteredChargers : discovery.filteredChargers.take(3).toList();
        return Column(
          children: chargers
              .map((charger) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ChargerCard(
                      name: charger.name,
                      power: '${charger.powerKw.round()} kW',
                      price: charger.pricePerKwh > 0 ? '₹${charger.pricePerKwh.round()}' : '—',
                      status: charger.chargerStatus,
                      address: _chargerLocation(charger),
                      rating: charger.rating > 0 ? charger.rating : null,
                      amenities: charger.amenitiesList,
                      onTap: () => context.go('/driver/charger/${charger.id}'),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  String _chargerLocation(Charger charger) {
    if (charger.address != null && charger.address!.trim().isNotEmpty) return charger.address!;
    return '${charger.latitude.toStringAsFixed(5)}, ${charger.longitude.toStringAsFixed(5)}';
  }
}
