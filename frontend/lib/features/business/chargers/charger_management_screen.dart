import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/widgets.dart';
import 'port_details_screen.dart';

class ChargerManagementScreen extends StatefulWidget {
  const ChargerManagementScreen({super.key});

  @override
  State<ChargerManagementScreen> createState() =>
      _ChargerManagementScreenState();
}

class _ChargerManagementScreenState extends State<ChargerManagementScreen> {
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
        return AppColors.success;
      case "paused":
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {},
        child: const Icon(Icons.add, color: AppColors.onPrimary),
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
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Charger Fleet",
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary.withValues(alpha: .4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.tune, color: AppColors.primary),
                  )
                ],
              ),
            ),

            // SEARCH
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: "Search chargers...",
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.border),
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

                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(18),
                    borderRadius: 18,
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
                                    AppColors.primary.withValues(alpha: .2),
                                    AppColors.secondary.withValues(alpha: .1)
                                  ],
                                ),
                              ),
                              child: const Icon(Icons.ev_station,
                                  color: AppColors.onPrimary, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    charger["name"],
                                    style: AppTypography.headlineSmall.copyWith(
                                      color: AppColors.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    charger["parking"],
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
                                charger["status"].toUpperCase(),
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _metric(
                                "${charger["power"]}", "kW", Icons.bolt),
                            _metric("₹${charger["price"]}", "/kWh",
                                Icons.currency_rupee),
                            _metric("${charger["reliability"]}%", "Health",
                                Icons.favorite),
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
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  charger["amenities"][i],
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
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
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.card,
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(color: AppColors.border),
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
                                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: AppColors.onPrimary,
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
                                  style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _metric(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.onPrimary.withValues(alpha: 0.8), size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.onPrimary,
          ),
        ),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.onPrimary.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
