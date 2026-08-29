import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';

/// Availability is managed from the live Chargers workspace. This compatibility
/// route intentionally delegates there so legacy deep links cannot show stale
/// local slot fixtures.
class AvailabilitySchedulerScreen extends StatelessWidget {
  const AvailabilitySchedulerScreen({super.key});

  @override
  Widget build(BuildContext context) => const DashboardScreen(initialTab: 1);
}
