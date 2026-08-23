import 'package:flutter/material.dart';

class AvailabilitySchedulerScreen extends StatefulWidget {
  const AvailabilitySchedulerScreen({super.key});

  @override
  State<AvailabilitySchedulerScreen> createState() =>
      _AvailabilitySchedulerScreenState();
}

class _AvailabilitySchedulerScreenState
    extends State<AvailabilitySchedulerScreen> {
  final Color bg = const Color(0xFF0A0F1F);
  final Color panel = const Color(0xFF111827);
  final Color cyan = const Color(0xFF00E5FF);
  final Color green = const Color(0xFF34D399);
  final Color amber = const Color(0xFFF59E0B);

  bool repeatWeekly = false;
  double price = 20;

  final List<Map<String, dynamic>> slots = [
    {
      "start": "09:00",
      "end": "11:00",
      "status": "active",
      "price": 18
    },
    {
      "start": "14:00",
      "end": "16:00",
      "status": "paused",
      "price": 20
    }
  ];

  Color slotColor(String status) =>
      status == "active" ? green : amber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Availability"),
            Text(
              "Port P1 • CCS2 • 60 kW",
              style: TextStyle(fontSize: 12, color: Colors.white60),
            )
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Day Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tuesday • 25 Aug",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Manage charging availability",
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            const Text(
              "Today's Slots",
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            ...slots.map((slot) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: slotColor(slot["status"]).withOpacity(.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 58,
                          decoration: BoxDecoration(
                            color: slotColor(slot["status"]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${slot["start"]} - ${slot["end"]}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "₹${slot["price"]}/kWh",
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              )
                            ],
                          ),
                        ),
                        Switch(
                          value: slot["status"] == "active",
                          activeColor: cyan,
                          onChanged: (v) {
                            setState(() {
                              slot["status"] =
                                  v ? "active" : "paused";
                            });
                          },
                        )
                      ],
                    ),
                  ),
                )),

            const SizedBox(height: 28),

            const Text(
              "Create New Slot",
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: timeBox("17:00")),
                      const SizedBox(width: 12),
                      Expanded(child: timeBox("20:00")),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const Icon(Icons.repeat,
                          color: Colors.white70),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "Repeat Weekly",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      Switch(
                        value: repeatWeekly,
                        activeColor: cyan,
                        onChanged: (v) =>
                            setState(() => repeatWeekly = v),
                      )
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Text(
                        "Price Override",
                        style: TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        "₹${price.toInt()}",
                        style: TextStyle(
                          color: cyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    ],
                  ),

                  Slider(
                    value: price,
                    min: 10,
                    max: 40,
                    activeColor: cyan,
                    onChanged: (v) =>
                        setState(() => price = v),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content:
                                Text("Availability Saved"),
                          ),
                        );
                      },
                      child: const Text(
                        "SAVE AVAILABILITY",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget timeBox(String time) {
    return Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        time,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}