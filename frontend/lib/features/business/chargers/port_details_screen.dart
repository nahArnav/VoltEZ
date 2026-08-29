import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/business_provider.dart';
import '../../../core/theme/colors.dart';

/// Live port details retained for deep links from older builds. It reads the
/// selected station from the business API and never creates local port rows.
class PortDetailsScreen extends StatelessWidget {
  const PortDetailsScreen({super.key, this.chargerId, this.chargerName});
  final String? chargerId;
  final String? chargerName;

  @override
  Widget build(BuildContext context) {
    final chargers = context.watch<BusinessProvider>().chargers;
    final charger = chargers.cast<Map<String, dynamic>?>().firstWhere(
          (item) => chargerId != null && item?['id']?.toString() == chargerId || chargerName != null && item?['name']?.toString() == chargerName,
          orElse: () => null,
        );
    final ports = (charger?['ports'] as List<dynamic>? ?? const []).whereType<Map>().toList();
    return Scaffold(
      appBar: AppBar(title: Text(charger?['name']?.toString() ?? chargerName ?? 'Port details')),
      body: ports.isEmpty
          ? const Center(child: Text('No live ports found for this charger.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: ports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final port = ports[index];
                final active = port['is_active'] as bool? ?? true;
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.power_rounded, color: active ? AppColors.success : AppColors.textMuted),
                    title: Text('Port ${port['port_number'] ?? index + 1}'),
                    subtitle: Text('${port['connector_type'] ?? 'Connector'} • ${port['max_power_kw'] ?? '—'} kW'),
                    trailing: Text(active ? 'ACTIVE' : 'INACTIVE'),
                  ),
                );
              },
            ),
    );
  }
}
