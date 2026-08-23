import 'package:flutter/material.dart';
import 'port_details_screen.dart';

class ChargerManagementScreen extends StatefulWidget {
  const ChargerManagementScreen({super.key});

  @override
  State<ChargerManagementScreen> createState() =>
      _ChargerManagementScreenState();
}

class _ChargerManagementScreenState extends State<ChargerManagementScreen> {
  final Color bg = const Color(0xFF0A0F1F);
  final Color card = const Color(0xFF111827);
  final Color cyan = const Color(0xFF00E5FF);
  final Color green = const Color(0xFF34D399);
  final Color amber = const Color(0xFFF59E0B);

  final List<Map<String, dynamic>> chargers = [
    {
      "name": "Basement Charger A",
      "power": 60,
      "price": 18.5,
      "status": "active",
      "reliability": 87,
      "parking": "B2 Near Elevator",
      "amenities": ["WiFi", "Food", "Restroom"]
    },
    {
      "name": "Ground Charger 02",
      "power": 30,
      "price": 15.0,
      "status": "paused",
      "reliability": 72,
      "parking": "Entrance Gate",
      "amenities": ["Cafe"]
    },
    {
      "name": "Fast Charger Pro",
      "power": 120,
      "price": 25.0,
      "status": "active",
      "reliability": 96,
      "parking": "VIP Zone",
      "amenities": ["WiFi", "Parking"]
    },
  ];

  Color statusColor(String status) {
    switch (status) {
      case "active":
        return green;
      case "paused":
        return amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: cyan,
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Charger Fleet",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: cyan.withOpacity(.4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.tune, color: cyan),
                  )
                ],
              ),
            ),

            // SEARCH
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search chargers...",
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.search, color: cyan),
                  filled: true,
                  fillColor: card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // LIST
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: chargers.length,
                itemBuilder: (context, index) {
                  final charger = chargers[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: cyan.withOpacity(.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cyan.withOpacity(.08),
                          blurRadius: 18,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 54,
                              width: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    cyan.withOpacity(.35),
                                    Colors.blue.withOpacity(.2)
                                  ],
                                ),
                              ),
                              child: Icon(Icons.ev_station,
                                  color: cyan, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    charger["name"],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    charger["parking"],
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor(charger["status"])
                                    .withOpacity(.15),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                charger["status"].toUpperCase(),
                                style: TextStyle(
                                  color: statusColor(charger["status"]),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            metric(
                                "${charger["power"]}", "kW", Icons.bolt, cyan),
                            metric("₹${charger["price"]}", "/kWh",
                                Icons.currency_rupee, Colors.white),
                            metric("${charger["reliability"]}%", "Health",
                                Icons.favorite, green),
                          ],
                        ),

                        const SizedBox(height: 18),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(
                              charger["amenities"].length,
                              (i) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  charger["amenities"][i],
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: cyan),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PortDetailsScreen(
                                        chargerName: charger["name"],
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  "Details",
                                  style: TextStyle(color: cyan),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cyan,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    charger["status"] =
                                        charger["status"] == "active"
                                            ? "paused"
                                            : "active";
                                  });
                                },
                                child: Text(
                                  charger["status"] == "active"
                                      ? "Pause"
                                      : "Resume",
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget metric(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}