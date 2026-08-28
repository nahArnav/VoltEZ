import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/widgets.dart';

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
        return AppColors.success;
      case "occupied":
        return AppColors.marigold;
      case "offline":
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Port Details",
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              widget.chargerName,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GlassCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 18,
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

                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    borderRadius: 18,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 52,
                              width: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: getColor(port["status"]).withValues(alpha: .12),
                              ),
                              child: const Icon(
                                Icons.power,
                                color: AppColors.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Port ${port["id"]}",
                                    style: AppTypography.headlineSmall.copyWith(
                                      color: AppColors.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${port["connector"]} • ${port["power"]} kW",
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.onPrimary.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.onPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                port["status"].toUpperCase(),
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.onPrimary,
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
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  "Schedule",
                                  style: TextStyle(color: AppColors.primary),
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
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
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
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.onPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onPrimary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
