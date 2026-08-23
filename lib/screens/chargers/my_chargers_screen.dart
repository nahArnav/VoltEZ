import 'package:flutter/material.dart';
import 'add_edit_charger_screen.dart';

const bg = Color(0xFF05090E);
const panel = Color(0xFF0B141C);
const cyan = Color(0xFF50F5FF);
const lime = Color(0xFFC9FF58);
const red = Color(0xFFFF6B6B);
const text = Color(0xFFF1F7FA);
const muted = Color(0xFF7D909D);

class MyChargersScreen extends StatelessWidget {
  const MyChargersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chargers = [
      {
        "name": "VoltHub Central",
        "location": "Shivajinagar, Pune",
        "ports": "3 / 5 Free",
        "power": "120 kW",
        "online": true,
      },
      {
        "name": "ChargeGrid West",
        "location": "Baner, Pune",
        "ports": "1 / 4 Free",
        "power": "60 kW",
        "online": true,
      },
      {
        "name": "Electra Point",
        "location": "Kothrud, Pune",
        "ports": "Offline",
        "power": "180 kW",
        "online": false,
      },
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text("My Chargers", style: TextStyle(color: text)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: cyan,
        foregroundColor: Colors.black,
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text("Add Charger"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: chargers.length,
        itemBuilder: (_, i) {
          final c = chargers[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: cyan.withOpacity(.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.ev_station,
                        color: cyan,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c["name"] as String,
                            style: const TextStyle(
                              color: text,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c["location"] as String,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (c["online"] as bool)
                            ? lime.withOpacity(.12)
                            : red.withOpacity(.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (c["online"] as bool) ? "ONLINE" : "OFFLINE",
                        style: TextStyle(
                          color: (c["online"] as bool) ? lime : red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.flash_on, color: cyan, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      c["power"] as String,
                      style: const TextStyle(color: text),
                    ),
                    const Spacer(),
                    const Icon(Icons.electrical_services,
                        color: cyan, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      c["ports"] as String,
                      style: const TextStyle(color: text),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: cyan),
                          foregroundColor: cyan,
                        ),
                        onPressed: () {},
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text("Edit"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cyan,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {},
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text("Details"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}