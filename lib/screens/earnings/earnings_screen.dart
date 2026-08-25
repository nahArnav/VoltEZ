import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

const Color _bg = Color(0xFF05090E);
const Color _panel = Color(0xFF0B141C);
const Color _cyan = Color(0xFF50F5FF);
const Color _amber = Color(0xFFFFC857);
const Color _danger = Color(0xFFFF5F6D);
const Color _text = Color(0xFFF1F8FF);
const Color _muted = Color(0xFF7990A1);

enum TimeFilter { daily, weekly, monthly, yearly }

class PayoutItem {
  final String id;
  final String date;
  final double amount;
  final String destination; // "HDFC Bank •••• 4092" or "UPI ••@okhdfcbank"
  final String status; // "paid", "processing", "failed"

  const PayoutItem({
    required this.id,
    required this.date,
    required this.amount,
    required this.destination,
    required this.status,
  });
}

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  TimeFilter _selectedFilter = TimeFilter.weekly;

  // Demo Settlement Account Data
  String _bankName = 'HDFC Bank';
  String _accountNumber = '•••• •••• •••• 4092';
  String _ifsc = 'HDFC0000240';
  String _upiId = 'voltez.host@okhdfcbank';

  // Demo Payout Transactions
  final List<PayoutItem> _payouts = const [
    PayoutItem(
      id: 'TXN-98402',
      date: '24 Aug 2026 • 18:30',
      amount: 18450.0,
      destination: 'HDFC Bank •••• 4092',
      status: 'paid',
    ),
    PayoutItem(
      id: 'TXN-98311',
      date: '21 Aug 2026 • 09:15',
      amount: 24300.0,
      destination: 'UPI ••@okhdfcbank',
      status: 'paid',
    ),
    PayoutItem(
      id: 'TXN-98105',
      date: '17 Aug 2026 • 21:00',
      amount: 14200.0,
      destination: 'HDFC Bank •••• 4092',
      status: 'processing',
    ),
    PayoutItem(
      id: 'TXN-97992',
      date: '12 Aug 2026 • 14:20',
      amount: 8900.0,
      destination: 'HDFC Bank •••• 4092',
      status: 'failed',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panel,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "FINANCIAL ANALYTICS",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Earnings & Payouts",
              style: TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settlement Account',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cyan.withOpacity(0.25)),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: _cyan, size: 18),
            ),
            onPressed: _showSettlementSheet,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceHero(),
            const SizedBox(height: 20),
            _buildTimeFilterTabs(),
            const SizedBox(height: 16),
            _buildChartCard(),
            const SizedBox(height: 24),
            _buildSectionHeader("PAYOUT & SETTLEMENTS", "Direct bank deposits"),
            const SizedBox(height: 12),
            _buildPayoutList(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BALANCE HERO CARD
  // ---------------------------------------------------------------------------

  Widget _buildBalanceHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 4),
                    Text(
                      "AUTO-SETTLE ACTIVE",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _showSettlementSheet,
                child: const Row(
                  children: [
                    Text(
                      "Edit Payouts",
                      style: TextStyle(color: _cyan, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Icon(Icons.chevron_right, color: _cyan, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            "Net Available for Payout",
            style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            "₹42,850.00",
            style: TextStyle(
              color: _text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("THIS WEEK", style: TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.bold)),
                      SizedBox(height: 3),
                      Text("₹65,490", style: TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: Colors.white10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("COMMISSION (5%)", style: TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.bold)),
                      SizedBox(height: 3),
                      Text("-₹3,274", style: TextStyle(color: _danger, fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: Colors.white10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("SESSIONS", style: TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.bold)),
                      SizedBox(height: 3),
                      Text("148", style: TextStyle(color: _cyan, fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TIME FILTER SELECTOR TABS
  // ---------------------------------------------------------------------------

  Widget _buildTimeFilterTabs() {
    final filters = [
      {'key': TimeFilter.daily, 'label': 'DAILY'},
      {'key': TimeFilter.weekly, 'label': 'WEEKLY'},
      {'key': TimeFilter.monthly, 'label': 'MONTHLY'},
      {'key': TimeFilter.yearly, 'label': 'YEARLY'},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = f['key'] as TimeFilter),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _cyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  f['label'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.black : _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INTERACTIVE REVENUE CHART (FL_CHART)
  // ---------------------------------------------------------------------------

  Widget _buildChartCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cyan.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "REVENUE TRAJECTORY",
                    style: TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  SizedBox(height: 2),
                  Text("Total Volume (₹)", style: TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "+18.4% vs last period",
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5000,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: Colors.white.withOpacity(0.04),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 5000,
                      getTitlesWidget: (val, meta) {
                        return Text(
                          '₹${(val / 1000).toInt()}k',
                          style: const TextStyle(color: _muted, fontSize: 9),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) {
                        final labels = _getChartLabels();
                        final index = val.toInt();
                        if (index >= 0 && index < labels.length) {
                          return Text(labels[index], style: const TextStyle(color: _muted, fontSize: 10));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (_getChartSpots().length - 1).toDouble(),
                minY: 0,
                maxY: 25000,
                lineBarsData: [
                  LineChartBarData(
                    spots: _getChartSpots(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: _cyan,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: _bg,
                        strokeWidth: 2,
                        strokeColor: _cyan,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _cyan.withOpacity(0.25),
                          _cyan.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getChartLabels() {
    switch (_selectedFilter) {
      case TimeFilter.daily:
        return ['06:00', '10:00', '14:00', '18:00', '22:00'];
      case TimeFilter.weekly:
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      case TimeFilter.monthly:
        return ['W1', 'W2', 'W3', 'W4'];
      case TimeFilter.yearly:
        return ['Q1', 'Q2', 'Q3', 'Q4'];
    }
  }

  List<FlSpot> _getChartSpots() {
    switch (_selectedFilter) {
      case TimeFilter.daily:
        return const [
          FlSpot(0, 3000),
          FlSpot(1, 8500),
          FlSpot(2, 6200),
          FlSpot(3, 14800),
          FlSpot(4, 9100),
        ];
      case TimeFilter.weekly:
        return const [
          FlSpot(0, 8000),
          FlSpot(1, 12500),
          FlSpot(2, 9400),
          FlSpot(3, 15800),
          FlSpot(4, 18200),
          FlSpot(5, 23000),
          FlSpot(6, 19500),
        ];
      case TimeFilter.monthly:
        return const [
          FlSpot(0, 12000),
          FlSpot(1, 17500),
          FlSpot(2, 14200),
          FlSpot(3, 21800),
        ];
      case TimeFilter.yearly:
        return const [
          FlSpot(0, 9000),
          FlSpot(1, 14000),
          FlSpot(2, 19000),
          FlSpot(3, 24000),
        ];
    }
  }

  // ---------------------------------------------------------------------------
  // PAYOUT HISTORY LIST
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10)),
          ],
        ),
        TextButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Downloading statement as PDF...")),
            );
          },
          icon: const Icon(Icons.download_rounded, color: _cyan, size: 14),
          label: const Text("Export", style: TextStyle(color: _cyan, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildPayoutList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _payouts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _payouts[index];
        return _buildPayoutTile(item);
      },
    );
  }

  Widget _buildPayoutTile(PayoutItem item) {
    Color badgeColor;
    IconData statusIcon;

    switch (item.status) {
      case 'paid':
        badgeColor = const Color(0xFF34D399);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'processing':
        badgeColor = _amber;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      default:
        badgeColor = _danger;
        statusIcon = Icons.error_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: badgeColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.destination,
                  style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  "${item.id} • ${item.date}",
                  style: const TextStyle(color: _muted, fontSize: 9),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹${item.amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}",
                style: const TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SETTLEMENT / BANK ACCOUNT MANAGEMENT SHEET
  // ---------------------------------------------------------------------------

  void _showSettlementSheet() {
    final bankCtrl = TextEditingController(text: _bankName);
    final accountCtrl = TextEditingController(text: _accountNumber);
    final ifscCtrl = TextEditingController(text: _ifsc);
    final upiCtrl = TextEditingController(text: _upiId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: 10),
                  const Text(
                    "Settlement Account",
                    style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: _muted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Text(
                "Payouts are automatically wired daily at 23:59 IST.",
                style: TextStyle(color: _muted, fontSize: 11),
              ),
              const SizedBox(height: 18),
              _buildSettlementField(bankCtrl, "Bank Name", Icons.business_rounded),
              const SizedBox(height: 12),
              _buildSettlementField(accountCtrl, "Account Number", Icons.tag_rounded),
              const SizedBox(height: 12),
              _buildSettlementField(ifscCtrl, "IFSC Code", Icons.qr_code_rounded),
              const SizedBox(height: 12),
              _buildSettlementField(upiCtrl, "Primary UPI ID (Alternative)", Icons.alternate_email_rounded),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      _bankName = bankCtrl.text.trim();
                      _accountNumber = accountCtrl.text.trim();
                      _ifsc = ifscCtrl.text.trim();
                      _upiId = upiCtrl.text.trim();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: _bg,
                        content: Text(
                          "Settlement account updated successfully!",
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    "SAVE SETTLEMENT DETAILS",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettlementField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: _text, fontSize: 13),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _cyan, size: 18),
        labelText: hint,
        labelStyle: const TextStyle(color: _muted, fontSize: 12),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _cyan, width: 1.2),
        ),
      ),
    );
  }
}