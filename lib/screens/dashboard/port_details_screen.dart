import 'package:flutter/material.dart';
import 'availability_scheduler_screen.dart';

const bg = Color(0xFF0A0F1F);
const panel = Color(0xFF111827);
const cyan = Color(0xFF00E5FF);
const green = Color(0xFF34D399);
const amber = Color(0xFFF59E0B);
const red = Color(0xFFEF4444);

class PortDetailsScreen extends StatefulWidget {
  final String chargerName;

  const PortDetailsScreen({
    super.key,
    required this.chargerName,
  });

  @override
  State<PortDetailsScreen> createState() => _PortDetailsScreenState();
}

class _PortDetailsScreenState extends State<PortDetailsScreen> {
  final List<Map<String, dynamic>> ports = [
    {
      "id": "P1",
      "connector": "CCS2",
      "power": 60,
      "status": "available",
    },
    {
      "id": "P2",
      "connector": "CCS2",
      "power": 60,
      "status": "occupied",
    },
    {
      "id": "P3",
      "connector": "Type 2",
      "power": 22,
      "status": "offline",
    },
    {
      "id": "P4",
      "connector": "CHAdeMO",
      "power": 50,
      "status": "available",
    },
  ];

  Color getColor(String status) {
    switch (status) {
      case "available":
        return green;
      case "occupied":
        return cyan;
      case "offline":
        return red;
      default:
        return amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Port Details"),
            Text(
              widget.chargerName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _TopMetric("4", "Ports"),
                  _TopMetric("2", "Available"),
                  _TopMetric("1", "In Use"),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: ports.length,
                itemBuilder: (context, index) {
                  final port = ports[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: getColor(port["status"]).withOpacity(.35),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 52,
                              width: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: getColor(port["status"]).withOpacity(.15),
                              ),
                              child: Icon(
                                Icons.power,
                                color: getColor(port["status"]),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Port ${port["id"]}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${port["connector"]} • ${port["power"]} kW",
                                    style: const TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: getColor(port["status"]).withOpacity(.15),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                port["status"].toUpperCase(),
                                style: TextStyle(
                                  color: getColor(port["status"]),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AvailabilitySchedulerScreen(),
                                  ),
                                );
                              },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: cyan),
                                ),
                                child: const Text(
                                  "Schedule",
                                  style: TextStyle(color: cyan),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    port["status"] =
                                        port["status"] == "available"
                                            ? "offline"
                                            : "available";
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cyan,
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(
                                  port["status"] == "offline"
                                      ? "Enable"
                                      : "Disable",
                                ),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopMetric extends StatelessWidget {
  final String value;
  final String label;

  const _TopMetric(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white60),
        ),
      ],
    );
  }
}