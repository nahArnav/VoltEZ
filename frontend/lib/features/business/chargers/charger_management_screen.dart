import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/business_provider.dart';
import '../../../core/theme/colors.dart';

/// Compatibility entry point for older routes. The owner dashboard is the
/// source of truth, so this screen deliberately renders only live API data.
class ChargerManagementScreen extends StatelessWidget {
  const ChargerManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>();
    if (business.isLoading && business.chargers.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final chargers = business.chargers;
    return Scaffold(
      appBar: AppBar(title: const Text('Chargers')),
      body: RefreshIndicator(
        onRefresh: business.load,
        child: chargers.isEmpty
            ? ListView(children: const [SizedBox(height: 220), Center(child: Text('No chargers registered'))])
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: chargers.length,
                itemBuilder: (context, index) {
                  final charger = chargers[index];
                  final status = charger['status']?.toString() ?? 'unknown';
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.ev_station_rounded, color: AppColors.primary),
                      title: Text(charger['name']?.toString() ?? 'Unnamed charger'),
                      subtitle: Text('${charger['power_kw'] ?? '—'} kW • ₹${charger['price_per_kwh'] ?? '—'}/kWh'),
                      trailing: Text(status.toUpperCase()),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
