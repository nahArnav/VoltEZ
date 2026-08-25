import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/session_provider.dart';
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

  // Mock data — replace with real API calls
  final double _batteryPercent = 72;
  final double _batteryKwh = 38.9;
  final double _rangeKm = 245;

  final List<Map<String, dynamic>> _nearbyChargers = [
    {
      'id': 'c1',
      'name': 'Phoenix Mall Charger',
      'address': 'Phoenix Mall, 2.3 km away',
      'power': '60 kW',
      'price': '₹14/kWh',
      'status': ChargerStatus.available,
      'amenities': ['WiFi', 'Food Court', 'Parking'],
      'rating': 4.6,
    },
    {
      'id': 'c2',
      'name': 'Highway Fast Charge',
      'address': 'Mumbai-Pune Expressway, 5.1 km',
      'power': '120 kW',
      'price': '₹18/kWh',
      'status': ChargerStatus.available,
      'amenities': ['Restroom', 'Cafe'],
      'rating': 4.2,
    },
    {
      'id': 'c3',
      'name': 'Tech Park Station',
      'address': 'Infosys Campus, 3.7 km',
      'power': '30 kW',
      'price': '₹11/kWh',
      'status': ChargerStatus.busy,
      'amenities': ['WiFi'],
      'rating': 4.8,
    },
  ];

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
              ..._nearbyChargers.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ChargerCard(
                      name: c['name'],
                      power: c['power'],
                      price: c['price'],
                      status: c['status'],
                      address: c['address'],
                      rating: c['rating'],
                      amenities: List<String>.from(c['amenities']),
                      onTap: () => context.go('/driver/charger/${c["id"]}'),
                    ),
                  )),
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
    final color = _batteryPercent > 50
        ? AppColors.success
        : _batteryPercent > 20
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
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
              Text('BATTERY STATUS', style: AppTypography.labelSmall.copyWith(
                color: color,
              )),
              Text(
                '${_batteryPercent.round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _batteryPercent / 100,
              color: color,
              backgroundColor: AppColors.surface,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _batteryMetric(Icons.bolt_rounded, '${_batteryKwh.toStringAsFixed(1)} kWh', 'Capacity', color),
              _batteryMetric(Icons.route_rounded, '${_rangeKm.round()} km', 'Range', AppColors.primary),
              _batteryMetric(Icons.ev_station_rounded, 'CCS2', 'Connector', AppColors.secondary),
            ],
          ),
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
          Expanded(
            child: ListView.builder(
              itemCount: _nearbyChargers.length,
              itemBuilder: (context, index) {
                final c = _nearbyChargers[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ChargerCard(
                    name: c['name'],
                    power: c['power'],
                    price: c['price'],
                    status: c['status'],
                    address: c['address'],
                    rating: c['rating'],
                    amenities: List<String>.from(c['amenities']),
                    onTap: () => context.go('/driver/charger/${c["id"]}'),
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
          _profileOption(
            Icons.directions_car_rounded,
            'My Vehicle',
            'Tata Nexon EV, 2024',
            () {},
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
}
