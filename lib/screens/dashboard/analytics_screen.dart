import 'package:flutter/material.dart';

const _bg = Color(0xFF05090E);
const _panel = Color(0xFF0B141C);
const _cyan = Color(0xFF50F5FF);
const _lime = Color(0xFFC9FF58);
const _violet = Color(0xFF9678FF);
const _text = Color(0xFFF1F7FA);
const _muted = Color(0xFF7D909D);

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String selectedPeriod = 'MONTH';

  final List<double> monthlyEnergy = [
    42,
    58,
    51,
    73,
    66,
    91,
    78,
    105,
    88,
    113,
    96,
    124,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 26),

              _buildPeriodSelector(),
              const SizedBox(height: 20),

              _buildMainEnergyCard(),
              const SizedBox(height: 18),

              _buildStatsGrid(),
              const SizedBox(height: 24),

              _buildSectionTitle(
                'ENERGY CONSUMPTION',
                'kWh usage over time',
              ),
              const SizedBox(height: 14),

              _buildChartCard(),
              const SizedBox(height: 24),

              _buildSectionTitle(
                'CHARGING INSIGHTS',
                'Your charging behavior',
              ),
              const SizedBox(height: 14),

              _buildInsightCards(),
              const SizedBox(height: 24),

              _buildSectionTitle(
                'ENVIRONMENTAL IMPACT',
                'Contribution through EV charging',
              ),
              const SizedBox(height: 14),

              _buildEnvironmentalCard(),
              const SizedBox(height: 24),

              _buildSectionTitle(
                'RECENT SESSIONS',
                'Latest charging activity',
              ),
              const SizedBox(height: 14),

              _buildSessionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _cyan.withOpacity(.18),
            ),
          ),
          child: const Icon(
            Icons.analytics_outlined,
            color: _cyan,
            size: 23,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ANALYTICS',
                style: TextStyle(
                  color: _text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Charging intelligence',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: _lime.withOpacity(.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _lime.withOpacity(.22),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.circle,
                color: _lime,
                size: 7,
              ),
              SizedBox(width: 6),
              Text(
                'LIVE',
                style: TextStyle(
                  color: _lime,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(.06),
        ),
      ),
      child: Row(
        children: [
          _periodButton('WEEK'),
          _periodButton('MONTH'),
          _periodButton('YEAR'),
        ],
      ),
    );
  }

  Widget _periodButton(String value) {
    final selected = selectedPeriod == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedPeriod = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? _cyan.withOpacity(.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(
                    color: _cyan.withOpacity(.28),
                  )
                : null,
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? _cyan : _muted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainEnergyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _cyan.withOpacity(.15),
        ),
        boxShadow: [
          BoxShadow(
            color: _cyan.withOpacity(.04),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TOTAL ENERGY',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Icon(
                Icons.bolt_rounded,
                color: _cyan.withOpacity(.7),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '1,247',
                style: TextStyle(
                  color: _text,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 7),
                child: Text(
                  'kWh',
                  style: TextStyle(
                    color: _cyan,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _lime.withOpacity(.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: _lime,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '+12.8%',
                      style: TextStyle(
                        color: _lime,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'vs previous month',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _statCard(
          icon: Icons.payments_outlined,
          title: 'TOTAL COST',
          value: '₹4,682',
          change: '+8.4%',
          color: _violet,
        ),
        _statCard(
          icon: Icons.ev_station_outlined,
          title: 'SESSIONS',
          value: '38',
          change: '+5',
          color: _cyan,
        ),
        _statCard(
          icon: Icons.timer_outlined,
          title: 'CHARGE TIME',
          value: '27.6h',
          change: '-3.2%',
          color: _lime,
        ),
        _statCard(
          icon: Icons.speed_outlined,
          title: 'AVG. SESSION',
          value: '32.8 kWh',
          change: '+4.1%',
          color: _violet,
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required String change,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(.055),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 18,
              ),
              const Spacer(),
              Text(
                change,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: _muted,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: _text,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 28,
          decoration: BoxDecoration(
            color: _cyan,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: _muted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartCard() {
    final maxValue = monthlyEnergy.reduce(
      (a, b) => a > b ? a : b,
    );

    return Container(
      height: 285,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(.055),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '124 kWh',
                style: TextStyle(
                  color: _cyan,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'current',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _cyan.withOpacity(.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'kWh / MONTH',
                  style: TextStyle(
                    color: _cyan,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                monthlyEnergy.length,
                (index) {
                  final value = monthlyEnergy[index];
                  final height =
                      (value / maxValue) * 155;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.end,
                        children: [
                          Container(
                            height: height,
                            decoration: BoxDecoration(
                              borderRadius:
                                  const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  _cyan.withOpacity(.25),
                                  _cyan.withOpacity(.85),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _months[index],
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _months = [
    'J',
    'F',
    'M',
    'A',
    'M',
    'J',
    'J',
    'A',
    'S',
    'O',
    'N',
    'D',
  ];

  Widget _buildInsightCards() {
    return Column(
      children: [
        _insightTile(
          icon: Icons.schedule_rounded,
          title: 'PEAK CHARGING TIME',
          value: '18:00 — 21:00',
          subtitle: 'Evening sessions dominate',
          color: _violet,
        ),
        const SizedBox(height: 10),
        _insightTile(
          icon: Icons.battery_charging_full_rounded,
          title: 'AVG. CHARGE LEVEL',
          value: '31% → 84%',
          subtitle: '53% average battery gain',
          color: _cyan,
        ),
        const SizedBox(height: 10),
        _insightTile(
          icon: Icons.location_on_outlined,
          title: 'MOST USED STATION',
          value: 'VoltHub Central',
          subtitle: '14 sessions this month',
          color: _lime,
        ),
      ],
    );
  }

  Widget _insightTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white.withOpacity(.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withOpacity(.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: color.withOpacity(.55),
            size: 13,
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _lime.withOpacity(.13),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: .72,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withOpacity(.05),
                  valueColor:
                      const AlwaysStoppedAnimation(_lime),
                ),
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '72%',
                      style: TextStyle(
                        color: _lime,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      GOAL',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 7,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CO₂ SAVINGS',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '286.4 kg',
                  style: TextStyle(
                    color: _text,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Equivalent to planting 13 trees',
                  style: TextStyle(
                    color: _lime,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(.055),
        ),
      ),
      child: Column(
        children: [
          _sessionRow(
            'VoltHub Central',
            'Today • 18:42',
            '38.4 kWh',
            '₹142',
            Icons.flash_on_rounded,
          ),
          _divider(),
          _sessionRow(
            'ChargeGrid West',
            'Yesterday • 20:15',
            '27.8 kWh',
            '₹109',
            Icons.ev_station_rounded,
          ),
          _divider(),
          _sessionRow(
            'VoltHub Central',
            '21 Aug • 19:08',
            '41.2 kWh',
            '₹156',
            Icons.flash_on_rounded,
          ),
          _divider(),
          _sessionRow(
            'Electra Point',
            '20 Aug • 17:34',
            '24.6 kWh',
            '₹96',
            Icons.ev_station_rounded,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      color: Colors.white.withOpacity(.045),
    );
  }

  Widget _sessionRow(
    String station,
    String time,
    String energy,
    String cost,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: _cyan.withOpacity(.07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: _cyan,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  station,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                energy,
                style: const TextStyle(
                  color: _cyan,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cost,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}