import 'package:flutter/material.dart';

const bg = Color(0xFF05090E);
const panel = Color(0xFF0B141C);
const cyan = Color(0xFF50F5FF);
const lime = Color(0xFFC9FF58);
const violet = Color(0xFF9678FF);
const text = Color(0xFFF1F7FA);
const muted = Color(0xFF7D909D);

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final payouts = [
      {
        "date": "23 Aug 2026",
        "station": "VoltHub Central",
        "amount": "₹1,850",
        "status": "Paid",
      },
      {
        "date": "22 Aug 2026",
        "station": "ChargeGrid West",
        "amount": "₹920",
        "status": "Pending",
      },
      {
        "date": "21 Aug 2026",
        "station": "VoltHub Central",
        "amount": "₹1,420",
        "status": "Paid",
      },
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: const BackButton(color: text),
        title: const Text(
          "Earnings & Payouts",
          style: TextStyle(color: text),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _revenueCard(),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _statCard(
                    "TODAY",
                    "₹2,770",
                    Icons.today,
                    cyan,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    "SESSIONS",
                    "18",
                    Icons.bolt,
                    lime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _statCard(
                    "THIS MONTH",
                    "₹42,850",
                    Icons.account_balance_wallet,
                    violet,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    "PENDING",
                    "₹920",
                    Icons.schedule,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            const Text(
              "RECENT PAYOUTS",
              style: TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 14),

            ...payouts.map((e) => _transaction(e)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _revenueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cyan.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "TOTAL REVENUE",
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.3,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "₹1,28,640",
            style: TextStyle(
              color: text,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.trending_up, color: lime, size: 16),
              SizedBox(width: 6),
              Text(
                "+18.4% from last month",
                style: TextStyle(
                  color: lime,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: .8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transaction(Map<String, String> t) {
    final paid = t["status"] == "Paid";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cyan.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: cyan,
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t["station"]!,
                  style: const TextStyle(
                    color: text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t["date"]!,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                t["amount"]!,
                style: const TextStyle(
                  color: text,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (paid ? lime : Colors.orange)
                      .withOpacity(.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t["status"]!,
                  style: TextStyle(
                    color: paid ? lime : Colors.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}