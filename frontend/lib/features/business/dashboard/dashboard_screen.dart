import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/glass_card.dart';
import '../chargers/charger_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _selectedIndex = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: const [
            _DashboardHome(),
            _ChargersPage(),
            _BookingsPage(),
            _AnalyticsPage(),
            _ProfilePage(),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

// ============================================================
// DASHBOARD HOME
// ============================================================

class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeader(),
              const SizedBox(height: 34),

              _SectionLabel(
                number: '01',
                title: 'TODAY AT A GLANCE',
              ),

              const SizedBox(height: 16),

              _buildStats(),

              const SizedBox(height: 34),

              _SectionLabel(
                number: '02',
                title: 'YOUR CHARGERS',
              ),

              const SizedBox(height: 16),

              _buildChargers(context),

              const SizedBox(height: 34),

              _SectionLabel(
                number: '03',
                title: "TODAY'S BOOKINGS",
              ),

              const SizedBox(height: 16),

              _buildBookings(),

              const SizedBox(height: 34),

              _SectionLabel(
                number: '04',
                title: 'NETWORK UTILIZATION',
              ),

              const SizedBox(height: 16),

              _buildUtilization(),

              const SizedBox(height: 34),

              _buildInsight(),

              const SizedBox(height: 30),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VOLTEZ / BUSINESS', style: AppTypography.sectionLabel.copyWith(
                color: AppColors.primary,
              )),
              const SizedBox(height: 12),
              Text('Good evening,', style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              )),
              const SizedBox(height: 2),
              Text('ABC Motors.', style: AppTypography.displaySmall),
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
          child: const Icon(Icons.notifications_none_rounded, color: AppColors.onPrimary, size: 23),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: '08',
                label: 'ACTIVE\nCHARGERS',
                accent: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBlock(
                value: '24',
                label: 'BOOKINGS\nTODAY',
                accent: AppColors.marigold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: '₹18.4K',
                label: 'REVENUE\nTODAY',
                accent: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBlock(
                value: '76%',
                label: 'NETWORK\nUTILIZATION',
                accent: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChargers(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      borderRadius: 16,
      child: Column(
        children: [
          _ChargerRow(
            name: 'Charger 01',
            type: 'DC FAST / 60 kW',
            status: 'AVAILABLE',
            statusColor: AppColors.success,
          ),
          const Divider(height: 1, color: AppColors.onPrimary),
          _ChargerRow(
            name: 'Charger 02',
            type: 'AC / 22 kW',
            status: 'IN USE',
            statusColor: AppColors.marigold,
          ),
          const Divider(height: 1, color: AppColors.onPrimary),
          _ChargerRow(
            name: 'Charger 03',
            type: 'DC FAST / 120 kW',
            status: 'OFFLINE',
            statusColor: AppColors.onPrimary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChargerManagementScreen()),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('ADD CHARGER'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(
                  color: AppColors.primary,
                  width: 1.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookings() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      borderRadius: 16,
      child: Column(
        children: const [
          _BookingRow(
            time: '10:00',
            customer: 'Tata Nexon EV',
            charger: 'Charger 01',
            status: 'CONFIRMED',
          ),
          Divider(height: 1, color: AppColors.onPrimary),
          _BookingRow(
            time: '12:30',
            customer: 'MG ZS EV',
            charger: 'Charger 02',
            status: 'UPCOMING',
          ),
          Divider(height: 1, color: AppColors.onPrimary),
          _BookingRow(
            time: '15:00',
            customer: 'Hyundai Ioniq 5',
            charger: 'Charger 01',
            status: 'UPCOMING',
          ),
        ],
      ),
    );
  }

  Widget _buildUtilization() {
    return GlassCard(
      accentColor: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      borderRadius: 18,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '76%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'LAST 7 DAYS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _Bar(value: 0.52, label: 'M'),
                _Bar(value: 0.67, label: 'T'),
                _Bar(value: 0.61, label: 'W'),
                _Bar(value: 0.82, label: 'T'),
                _Bar(value: 0.76, label: 'F'),
                _Bar(value: 0.91, label: 'S'),
                _Bar(value: 0.76, label: 'S'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsight() {
    return GlassCard(
      accentColor: AppColors.primary,
      padding: const EdgeInsets.all(20),
      borderRadius: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.bolt_rounded, color: AppColors.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOLTEZ INSIGHT',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Charger 03 is underutilized between 11 AM – 3 PM.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'View recommendation →',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// COMPONENTS
// ============================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.number,
    required this.title,
  });

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(number, style: AppTypography.sectionNumber),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: AppColors.border),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppTypography.sectionLabel),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.label,
    required this.accent,
  });

  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accentColor: AppColors.primary,
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: SizedBox(
        height: 80,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 28,
              height: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              value,
              style: AppTypography.headlineLarge.copyWith(
                color: AppColors.onPrimary,
              ),
            ),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.onPrimary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargerRow extends StatelessWidget {
  const _ChargerRow({
    required this.name,
    required this.type,
    required this.status,
    required this.statusColor,
  });

  final String name;
  final String type;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.ev_station_rounded, color: AppColors.onPrimary, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  type,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: AppTypography.labelMedium.copyWith(
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({
    required this.time,
    required this.customer,
    required this.charger,
    required this.status,
  });

  final String time;
  final String customer;
  final String charger;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              time,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  charger,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: value,
              child: Container(
                width: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// BOTTOM NAVIGATION
// ============================================================

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.grid_view_rounded, 'Home'),
      (Icons.ev_station_rounded, 'Chargers'),
      (Icons.calendar_today_rounded, 'Bookings'),
      (Icons.bar_chart_rounded, 'Analytics'),
      (Icons.person_outline_rounded, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final selected = index == selectedIndex;

          return GestureDetector(
            onTap: () => onChanged(index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    items[index].$1,
                    size: 20,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[index].$2,
                    style: AppTypography.labelMedium.copyWith(
                      color: selected ? AppColors.primary : AppColors.textMuted,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================
// PLACEHOLDER PAGES
// ============================================================
class _ChargersPage extends StatelessWidget {
  const _ChargersPage();

  @override
  Widget build(BuildContext context) {
    return const ChargerManagementScreen();
  }
}

class _BookingsPage extends StatelessWidget {
  const _BookingsPage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Bookings',
        style: AppTypography.headlineLarge.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _AnalyticsPage extends StatelessWidget {
  const _AnalyticsPage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Analytics',
        style: AppTypography.headlineLarge.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
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
            child: Icon(Icons.business_rounded,
                color: AppColors.primary, size: 44),
          ),
          const SizedBox(height: 16),
          Text('ABC Motors', style: AppTypography.displaySmall),
          const SizedBox(height: 4),
          Text('Business Owner', style: AppTypography.bodyMedium),
          const SizedBox(height: 32),

          // Profile options
          _profileOption(
            Icons.business_rounded,
            'Business Profile',
            'Manage your business details',
            () {},
          ),
          _profileOption(
            Icons.ev_station_rounded,
            'Charger Fleet',
            'Manage your chargers and ports',
            () {},
          ),
          _profileOption(
            Icons.receipt_long_rounded,
            'Earnings',
            'View revenue and settlements',
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
            'Sign Out',
            'Sign out of your account',
            () async {
              final auth = context.read<AuthProvider>();
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _profileOption(
      IconData icon, String title, String subtitle, VoidCallback onTap,
      {bool isDestructive = false}) {
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
                  color: isDestructive
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? AppColors.error : AppColors.primary,
                  size: 22,
                ),
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
}
