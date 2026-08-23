import 'package:flutter/material.dart';
import '../../widgets/ai_copilot_drawer.dart';

class AiRecommendationsScreen extends StatefulWidget {
  const AiRecommendationsScreen({super.key});

  @override
  State<AiRecommendationsScreen> createState() =>
      _AiRecommendationsScreenState();
}

class _AiRecommendationsScreenState
    extends State<AiRecommendationsScreen> {
  static const Color bg = Color(0xFF0A0F1F);
  static const Color panel = Color(0xFF111827);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color green = Color(0xFF34D399);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFFB7185);

  final List<Map<String, dynamic>> recommendations = [
    {
      "id": "rec-123",
      "type": "availability_and_pricing",
      "date": "Tuesday • 25 Aug",
      "start": "14:00",
      "end": "17:00",
      "price": 20,
      "forecast": 18,
      "nearby": 5,
      "utilization": 0.82,
      "confidence": 0.91,
      "reason":
          "Demand is forecast to rise while nearby charging supply remains low.",
      "status": "pending",
    },
    {
      "id": "rec-124",
      "type": "availability_and_pricing",
      "date": "Thursday • 27 Aug",
      "start": "18:00",
      "end": "21:00",
      "price": 22,
      "forecast": 24,
      "nearby": 7,
      "utilization": 0.88,
      "confidence": 0.87,
      "reason":
          "Evening demand is expected to increase due to high traffic in the area.",
      "status": "pending",
    },
  ];

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
            Text(
              "AI Recommendations",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Smart availability & pricing",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: cyan,
        foregroundColor: Colors.black,
        onPressed: () => AiCopilotSheet.show(context),
        icon: const Icon(Icons.auto_awesome),
        label: const Text(
          "ASK AI COPILOT",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            const SizedBox(height: 24),

            const Text(
              "Recommended Actions",
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            ...recommendations.map(
              (recommendation) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _buildRecommendationCard(
                  recommendation,
                ),
              ),
            ),

            const SizedBox(height: 10),

            _buildHowItWorks(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cyan.withOpacity(.18),
        ),
        boxShadow: [
          BoxShadow(
            color: cyan.withOpacity(.04),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cyan.withOpacity(.09),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: cyan.withOpacity(.18),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: cyan,
              size: 27,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  "AI Station Intelligence",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Recommendations are generated using "
                  "demand, nearby supply and charger "
                  "utilization.",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // RECOMMENDATION CARD
  // ------------------------------------------------------------

  Widget _buildRecommendationCard(
    Map<String, dynamic> recommendation,
  ) {
    final double confidence =
        recommendation["confidence"];

    final double utilization =
        recommendation["utilization"];

    final String status =
        recommendation["status"];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == "pending"
              ? cyan.withOpacity(.2)
              : Colors.white.withOpacity(.06),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cyan.withOpacity(.08),
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: cyan,
                      size: 12,
                    ),
                    SizedBox(width: 5),
                    Text(
                      "AI RECOMMENDATION",
                      style: TextStyle(
                        color: cyan,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _statusBadge(status),
            ],
          ),

          const SizedBox(height: 18),

          const Text(
            "Open Availability",
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            recommendation["reason"],
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Date
          _infoRow(
            Icons.calendar_today_rounded,
            "Recommended Date",
            recommendation["date"],
          ),

          const SizedBox(height: 13),

          // Time
          _infoRow(
            Icons.schedule_rounded,
            "Availability",
            "${recommendation["start"]} – "
                "${recommendation["end"]}",
          ),

          const SizedBox(height: 13),

          // Price
          _infoRow(
            Icons.currency_rupee_rounded,
            "Suggested Price",
            "₹${recommendation["price"]}/kWh",
            valueColor: cyan,
          ),

          const SizedBox(height: 20),

          // Metrics
          Row(
            children: [
              _metric(
                "FORECAST",
                "${recommendation["forecast"]}",
                "sessions",
              ),
              const SizedBox(width: 8),
              _metric(
                "NEARBY",
                "${recommendation["nearby"]}",
                "chargers",
              ),
              const SizedBox(width: 8),
              _metric(
                "UTILIZATION",
                "${(utilization * 100).toInt()}%",
                "predicted",
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Confidence
          _buildConfidence(confidence),

          const SizedBox(height: 20),

          if (status == "pending")
            _buildActionButtons(recommendation)
          else
            _buildCompletedState(status),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // INFO ROW
  // ------------------------------------------------------------

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color valueColor = Colors.white,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white38,
          size: 18,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // METRIC
  // ------------------------------------------------------------

  Widget _metric(
    String label,
    String value,
    String subtitle,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.035),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: Colors.white.withOpacity(.04),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 7,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CONFIDENCE
  // ------------------------------------------------------------

  Widget _buildConfidence(double confidence) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "AI Confidence",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Text(
              "${(confidence * 100).toInt()}%",
              style: const TextStyle(
                color: green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: confidence,
            minHeight: 5,
            backgroundColor: Colors.white10,
            valueColor:
                const AlwaysStoppedAnimation<Color>(
              green,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // ACTION BUTTONS
  // ------------------------------------------------------------

  Widget _buildActionButtons(
    Map<String, dynamic> recommendation,
  ) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 47,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: cyan,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              setState(() {
                recommendation["status"] =
                    "accepted";
              });

              _showMessage(
                "Recommendation accepted",
                green,
              );
            },
            icon: const Icon(
              Icons.check_rounded,
              size: 18,
            ),
            label: const Text(
              "ACCEPT RECOMMENDATION",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),

        const SizedBox(height: 9),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(
                    color: Colors.white12,
                  ),
                  minimumSize:
                      const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(11),
                  ),
                ),
                onPressed: () {
                  _showEditDialog(
                    recommendation,
                  );
                },
                child: const Text(
                  "EDIT",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: red,
                  side: BorderSide(
                    color: red.withOpacity(.25),
                  ),
                  minimumSize:
                      const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(11),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    recommendation["status"] =
                        "rejected";
                  });

                  _showMessage(
                    "Recommendation rejected",
                    red,
                  );
                },
                child: const Text(
                  "REJECT",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // STATUS
  // ------------------------------------------------------------

  Widget _statusBadge(String status) {
    Color color;

    switch (status) {
      case "accepted":
        color = green;
        break;
      case "rejected":
        color = red;
        break;
      case "edited":
        color = amber;
        break;
      default:
        color = cyan;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCompletedState(String status) {
    final Color color = status == "accepted"
        ? green
        : status == "rejected"
            ? red
            : amber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            status == "accepted"
                ? Icons.check_circle_outline
                : Icons.info_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 9),
          Text(
            "Recommendation ${status.toUpperCase()}",
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // EDIT DIALOG
  // ------------------------------------------------------------

  void _showEditDialog(
    Map<String, dynamic> recommendation,
  ) {
    final TextEditingController priceController =
        TextEditingController(
      text: recommendation["price"].toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            "Edit Recommendation",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                "Suggested price",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  prefixText: "₹ ",
                  prefixStyle: const TextStyle(
                    color: cyan,
                  ),
                  suffixText: "/kWh",
                  suffixStyle: const TextStyle(
                    color: Colors.white38,
                  ),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text(
                "CANCEL",
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cyan,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final newPrice = double.tryParse(
                  priceController.text,
                );

                if (newPrice != null) {
                  setState(() {
                    recommendation["price"] =
                        newPrice;
                    recommendation["status"] =
                        "edited";
                  });
                }

                Navigator.pop(context);

                _showMessage(
                  "Recommendation updated",
                  amber,
                );
              },
              child: const Text(
                "SAVE",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // HOW IT WORKS
  // ------------------------------------------------------------

  Widget _buildHowItWorks() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(.05),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            "How AI decides",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _reasonRow(
            Icons.bar_chart_rounded,
            "Demand Forecast",
            "Predicts charging demand by time.",
          ),
          const SizedBox(height: 14),
          _reasonRow(
            Icons.location_on_outlined,
            "Nearby Supply",
            "Checks available chargers nearby.",
          ),
          const SizedBox(height: 14),
          _reasonRow(
            Icons.speed_rounded,
            "Utilization",
            "Estimates expected charger usage.",
          ),
        ],
      ),
    );
  }

  Widget _reasonRow(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: cyan,
          size: 19,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  void _showMessage(
    String message,
    Color color,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: panel,
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: color,
              size: 19,
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}