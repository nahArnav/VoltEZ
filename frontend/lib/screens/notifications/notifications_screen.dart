import 'package:flutter/material.dart';

const bg = Color(0xFF05090E);
const panel = Color(0xFF0D1821);
const cyan = Color(0xFF50F5FF);
const lime = Color(0xFFC9FF58);
const orange = Color(0xFFFFB84D);
const red = Color(0xFFFF6B6B);
const text = Color(0xFFF1F8FF);
const muted = Color(0xFF7990A1);

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {
        "type": "booking",
        "title": "New booking received",
        "msg": "Tata Nexon EV booked Charger 01 • 6:30 PM",
        "time": "2 min ago",
      },
      {
        "type": "payment",
        "title": "Payout credited",
        "msg": "₹1,850 has been transferred successfully.",
        "time": "1 hr ago",
      },
      {
        "type": "warning",
        "title": "Charger 03 offline",
        "msg": "No heartbeat detected for 15 minutes.",
        "time": "3 hrs ago",
      },
      {
        "type": "booking",
        "title": "Booking cancelled",
        "msg": "MG ZS EV cancelled today's reservation.",
        "time": "Yesterday",
      },
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: const BackButton(color: text),
        title: const Text(
          "Notifications",
          style: TextStyle(color: text),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              "Mark all",
              style: TextStyle(color: cyan),
            ),
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final n = notifications[index];

          IconData icon = Icons.notifications;
          Color color = cyan;

          switch (n["type"]) {
            case "booking":
              icon = Icons.calendar_today;
              color = cyan;
              break;
            case "payment":
              icon = Icons.account_balance_wallet;
              color = lime;
              break;
            case "warning":
              icon = Icons.warning_amber_rounded;
              color = orange;
              break;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n["title"]!,
                        style: const TextStyle(
                          color: text,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        n["msg"]!,
                        style: const TextStyle(
                          color: muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        n["time"]!,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}