import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/widgets.dart';

class AvailabilitySchedulerScreen extends StatefulWidget {
  const AvailabilitySchedulerScreen({super.key});

  @override
  State<AvailabilitySchedulerScreen> createState() =>
      _AvailabilitySchedulerScreenState();
}

class _AvailabilitySchedulerScreenState
    extends State<AvailabilitySchedulerScreen> {
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
      status == "active" ? AppColors.success : AppColors.warning;

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
              "Availability",
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              "Port P1 • CCS2 • 60 kW",
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
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
            GlassCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tuesday • 25 Aug",
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Manage charging availability",
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            Text(
              "Today's Slots",
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.onPrimary,
              ),
            ),

            const SizedBox(height: 14),

            ...slots.map((slot) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 16,
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 58,
                          decoration: BoxDecoration(
                            color: AppColors.onPrimary.withValues(alpha: 0.4),
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
                                style: AppTypography.headlineSmall.copyWith(
                                  color: AppColors.onPrimary,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "₹${slot["price"]}/kWh",
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.onPrimary.withValues(alpha: 0.7),
                                ),
                              )
                            ],
                          ),
                        ),
                        Switch(
                          value: slot["status"] == "active",
                          activeThumbColor: AppColors.primary,
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

            Text(
              "Create New Slot",
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.onPrimary,
              ),
            ),

            const SizedBox(height: 14),

            GlassCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 18,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _timeBox("17:00")),
                      const SizedBox(width: 12),
                      Expanded(child: _timeBox("20:00")),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Icon(Icons.repeat, color: AppColors.onPrimary.withValues(alpha: 0.7)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Repeat Weekly",
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                      Switch(
                        value: repeatWeekly,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) =>
                            setState(() => repeatWeekly = v),
                      )
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Text(
                        "Price Override",
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "₹${price.toInt()}",
                        style: AppTypography.headlineMedium.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      )
                    ],
                  ),

                  Slider(
                    value: price,
                    min: 10,
                    max: 40,
                    activeColor: AppColors.primary,
                    onChanged: (v) =>
                        setState(() => price = v),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
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
                      child: Text(
                        "SAVE AVAILABILITY",
                        style: AppTypography.buttonText.copyWith(
                          color: AppColors.onPrimary,
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

  Widget _timeBox(String time) {
    return Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        time,
        style: AppTypography.headlineMedium.copyWith(
          color: AppColors.onPrimary,
        ),
      ),
    );
  }
}
