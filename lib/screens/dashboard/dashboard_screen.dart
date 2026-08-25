import 'package:flutter/material.dart';
import 'charger_management_screen.dart';

// Shared Voltez AI-mobility command-centre palette.
const _ivory = Color(0xFF05090E);
const _ink = Color(0xFFF1F8FF);
const _forest = Color(0xFF50F5FF);
const _rust = Color(0xFFC9FF58);
const _fadeInk = Color(0xFF7990A1);
const _panel = Color(0xFF0D1821);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ivory,
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
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeader(),
              const SizedBox(height: 34),

              const _SectionLabel(
                number: '01',
                title: 'TODAY AT A GLANCE',
              ),

              const SizedBox(height: 16),

              _buildStats(),

              const SizedBox(height: 34),

              const _SectionLabel(
                number: '02',
                title: 'YOUR CHARGERS',
              ),

              const SizedBox(height: 16),

              _buildChargers(),

              const SizedBox(height: 34),

              const _SectionLabel(
                number: '03',
                title: "TODAY'S BOOKINGS",
              ),

              const SizedBox(height: 16),

              _buildBookings(),

              const SizedBox(height: 34),

              const _SectionLabel(
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
              const Text(
                'VOLTEZ / BUSINESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: _forest,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Good evening,',
                style: TextStyle(
                  fontSize: 17,
                  color: _fadeInk,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'ABC Motors.',
                style: TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  height: 1,
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _forest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
            size: 23,
          ),
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
                accent: _forest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBlock(
                value: '24',
                label: 'BOOKINGS\nTODAY',
                accent: _rust,
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
                accent: _ink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBlock(
                value: '76%',
                label: 'NETWORK\nUTILIZATION',
                accent: _forest,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChargers() {
    return Column(
      children: [
        const _ChargerRow(
          name: 'Charger 01',
          type: 'DC FAST / 60 kW',
          status: 'AVAILABLE',
          statusColor: _forest,
        ),
        const Divider(height: 1),
        const _ChargerRow(
          name: 'Charger 02',
          type: 'AC / 22 kW',
          status: 'IN USE',
          statusColor: _rust,
        ),
        const Divider(height: 1),
        const _ChargerRow(
          name: 'Charger 03',
          type: 'DC FAST / 120 kW',
          status: 'OFFLINE',
          statusColor: _fadeInk,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('ADD CHARGER'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _forest,
              side: const BorderSide(
                color: _forest,
                width: 1.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookings() {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: const [
          _BookingRow(
            time: '10:00',
            customer: 'Tata Nexon EV',
            charger: 'Charger 01',
            status: 'CONFIRMED',
          ),
          Divider(height: 1),
          _BookingRow(
            time: '12:30',
            customer: 'MG ZS EV',
            charger: 'Charger 02',
            status: 'UPCOMING',
          ),
          Divider(height: 1),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: _forest,
        borderRadius: BorderRadius.circular(18),
      ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _forest.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _rust,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOLTEZ INSIGHT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: _rust,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Charger 03 is underutilized between 11 AM – 3 PM.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'View recommendation →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _forest,
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
        Text(
          number,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _rust,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: _ink.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: _fadeInk,
          ),
        ),
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
    return Container(
      height: 112,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
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
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              height: 1.25,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: _fadeInk,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _forest.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.ev_station_rounded,
              color: _forest,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  type,
                  style: const TextStyle(
                    fontSize: 10,
                    color: _fadeInk,
                    letterSpacing: 0.5,
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
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _ink,
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  charger,
                  style: const TextStyle(
                    fontSize: 10,
                    color: _fadeInk,
                  ),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: _forest,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.label,
  });

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
        color: _panel,
        border: Border(
          top: BorderSide(
            color: _ink.withValues(alpha: 0.08),
          ),
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
                    ? _forest.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    items[index].$1,
                    size: 20,
                    color: selected ? _forest : _fadeInk,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[index].$2,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? _forest : _fadeInk,
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
    return const Center(
      child: Text(
        'Bookings',
        style: TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _AnalyticsPage extends StatelessWidget {
  const _AnalyticsPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Analytics',
        style: TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Profile',
        style: TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
