import 'package:flutter/material.dart';

const bg = Color(0xFF05090E);
const panel = Color(0xFF0B141C);
const cyan = Color(0xFF50F5FF);
const lime = Color(0xFFC9FF58);
const red = Color(0xFFFF6B6B);
const orange = Color(0xFFFFB84D);
const text = Color(0xFFF1F7FA);
const muted = Color(0xFF7D909D);

class ChargerDetailsScreen extends StatefulWidget {
  const ChargerDetailsScreen({super.key});

  @override
  State<ChargerDetailsScreen> createState() =>
      _ChargerDetailsScreenState();
}

class _ChargerDetailsScreenState
    extends State<ChargerDetailsScreen> {
  final List<Map<String, dynamic>> ports = [
    {
      "id": "P1",
      "type": "CCS2",
      "power": "120 kW",
      "status": "Available",
      "enabled": true,
    },
    {
      "id": "P2",
      "type": "CCS2",
      "power": "120 kW",
      "status": "Occupied",
      "enabled": true,
    },
    {
      "id": "P3",
      "type": "Type-2",
      "power": "22 kW",
      "status": "Maintenance",
      "enabled": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: const BackButton(color: text),
        title: const Text(
          "Charger Details",
          style: TextStyle(color: text),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stationCard(),
            const SizedBox(height: 22),

            const Text(
              "CHARGING PORTS",
              style: TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 12),

            ...ports.asMap().entries.map(
                  (entry) => _portCard(entry.key),
                ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: cyan,
                  side: const BorderSide(color: cyan),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text("ADD NEW PORT"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _stationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: cyan.withOpacity(.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.ev_station,
                  color: cyan,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "VoltHub Central",
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Shivajinagar, Pune",
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              )
            ],
          ),
          const Divider(height: 24, color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _Info("Ports", "5"),
              _Info("Free", "3"),
              _Info("Rate", "₹18"),
            ],
          )
        ],
      ),
    );
  }

  Widget _portCard(int index) {
    final port = ports[index];

    Color statusColor = lime;

    if (port["status"] == "Occupied") statusColor = orange;
    if (port["status"] == "Maintenance") statusColor = red;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              Text(
                port["id"],
                style: const TextStyle(
                  color: cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "${port["type"]} • ${port["power"]}",
                  style: const TextStyle(color: text),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  port["status"],
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                "Enable Port",
                style: TextStyle(color: muted),
              ),
              const Spacer(),
              Switch(
                value: port["enabled"],
                activeColor: lime,
                onChanged: (v) {
                  setState(() {
                    ports[index]["enabled"] = v;
                    ports[index]["status"] =
                        v ? "Available" : "Maintenance";
                  });
                },
              )
            ],
          ),
          const Divider(color: Colors.white12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cyan,
                    side: const BorderSide(color: cyan),
                  ),
                  child: const Text("Edit"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: red,
                  ),
                  onPressed: () {},
                  child: const Text("Remove"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String title;
  final String value;

  const _Info(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: cyan,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: muted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}