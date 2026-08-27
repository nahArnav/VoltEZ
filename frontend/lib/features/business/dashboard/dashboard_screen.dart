import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/theme/colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BusinessProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.business == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (provider.needsOnboarding) {
          return _BusinessOnboarding(provider: provider);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(provider.business?['name']?.toString() ?? 'VoltEZ Business'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: provider.isLoading ? null : provider.load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (provider.errorMessage != null)
                  MaterialBanner(
                    content: Text(provider.errorMessage!),
                    actions: [
                      TextButton(onPressed: provider.load, child: const Text('RETRY')),
                    ],
                  ),
                if (provider.isLoading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      _Overview(provider: provider),
                      _Chargers(provider: provider),
                      _Bookings(provider: provider),
                      _Analytics(provider: provider),
                      _Profile(provider: provider),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (value) => setState(() => _tab = value),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.ev_station_rounded), label: 'Chargers'),
              NavigationDestination(icon: Icon(Icons.event_note_rounded), label: 'Bookings'),
              NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'AI'),
              NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}

class _BusinessOnboarding extends StatefulWidget {
  const _BusinessOnboarding({required this.provider});
  final BusinessProvider provider;

  @override
  State<_BusinessOnboarding> createState() => _BusinessOnboardingState();
}

class _BusinessOnboardingState extends State<_BusinessOnboarding> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _address = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_name, _category, _address, _latitude, _longitude]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your charging business')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.storefront_rounded, size: 72, color: AppColors.primary),
                const SizedBox(height: 20),
                _field(_name, 'Business name'),
                _field(_category, 'Category'),
                _field(_address, 'Address'),
                Row(children: [
                  Expanded(child: _field(_latitude, 'Latitude', numeric: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_longitude, 'Longitude', numeric: true)),
                ]),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: widget.provider.isLoading ? null : _submit,
                  child: const Text('CREATE BUSINESS PROFILE'),
                ),
                if (widget.provider.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(widget.provider.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool numeric = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
          validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
        ),
      );

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final latitude = double.tryParse(_latitude.text);
    final longitude = double.tryParse(_longitude.text);
    if (latitude == null || longitude == null) return;
    await widget.provider.createBusiness(
      name: _name.text.trim(),
      category: _category.text.trim(),
      address: _address.text.trim(),
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.provider});
  final BusinessProvider provider;

  @override
  Widget build(BuildContext context) {
    final active = provider.chargers.where((c) => c['status'] == 'available').length;
    final confirmed = provider.bookings.where((b) => b['status'] == 'confirmed').length;
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Live operations', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(label: 'Chargers', value: '${provider.chargers.length}', icon: Icons.ev_station),
              _Metric(label: 'Available', value: '$active', icon: Icons.bolt),
              _Metric(label: 'Bookings', value: '${provider.bookings.length}', icon: Icons.event),
              _Metric(label: 'Confirmed', value: '$confirmed', icon: Icons.verified),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent bookings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (provider.bookings.isEmpty)
            const _Empty(text: 'No bookings yet. New driver bookings will appear here.')
          else
            ...provider.bookings.take(5).map(_bookingTile),
        ],
      ),
    );
  }
}

class _Chargers extends StatelessWidget {
  const _Chargers({required this.provider});
  final BusinessProvider provider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCharger(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('Add charger'),
      ),
      body: provider.chargers.isEmpty
          ? const _Empty(text: 'Add your first physical charger to start accepting bookings.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: provider.chargers.length,
              itemBuilder: (context, index) {
                final charger = provider.chargers[index];
                final ports = charger['ports'] as List<dynamic>? ?? const [];
                final available = charger['status'] == 'available';
                return Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.ev_station_rounded, color: AppColors.primary),
                    title: Text(charger['name']?.toString() ?? 'Charger'),
                    subtitle: Text('${charger['power_kw']} kW • ${charger['status']} • ${ports.length} ports'),
                    trailing: Switch(
                      value: available,
                      onChanged: (value) => provider.setChargerStatus(
                        charger['id'].toString(),
                        value ? 'available' : 'unavailable',
                      ),
                    ),
                    children: [
                      for (final raw in ports)
                        ListTile(
                          leading: const Icon(Icons.power_rounded),
                          title: Text('Port ${(raw as Map)['port_number']} • ${raw['max_power_kw']} kW'),
                          subtitle: Text(raw['is_active'] == true ? 'Active' : 'Inactive'),
                          trailing: TextButton(
                            onPressed: () => _showAvailability(context, provider, raw['id'].toString()),
                            child: const Text('SCHEDULE'),
                          ),
                        ),
                      OverflowBar(children: [
                        TextButton.icon(
                          onPressed: () => _showAddPort(context, provider, charger),
                          icon: const Icon(Icons.add),
                          label: const Text('ADD PORT'),
                        ),
                      ]),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _Bookings extends StatelessWidget {
  const _Bookings({required this.provider});
  final BusinessProvider provider;

  @override
  Widget build(BuildContext context) => provider.bookings.isEmpty
      ? const _Empty(text: 'No customer bookings have been recorded yet.')
      : RefreshIndicator(
          onRefresh: provider.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: provider.bookings.map(_bookingTile).toList(),
          ),
        );
}

class _Analytics extends StatelessWidget {
  const _Analytics({required this.provider});
  final BusinessProvider provider;

  @override
  Widget build(BuildContext context) => provider.recommendations.isEmpty
      ? const _Empty(text: 'No off-peak opportunity is currently strong enough to recommend.')
      : RefreshIndicator(
          onRefresh: provider.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: provider.recommendations.map((item) => Card(
              child: ListTile(
                leading: const Icon(Icons.auto_awesome, color: AppColors.primary),
                title: Text(item['recommended_action']?.toString() ?? 'Recommendation'),
                subtitle: Text('Expected demand: ${item['expected_demand']} • Confidence: ${item['confidence']}'),
                trailing: Text('${item['suggested_discount_pct'] ?? 0}%'),
              ),
            )).toList(),
          ),
        );
}

class _Profile extends StatelessWidget {
  const _Profile({required this.provider});
  final BusinessProvider provider;

  @override
  Widget build(BuildContext context) {
    final business = provider.business!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CircleAvatar(radius: 38, child: Icon(Icons.storefront, size: 38)),
        const SizedBox(height: 16),
        Center(child: Text(business['name'].toString(), style: Theme.of(context).textTheme.headlineSmall)),
        Center(child: Text('${business['category']} • ${business['verification_status']}')),
        const SizedBox(height: 24),
        ListTile(leading: const Icon(Icons.location_on), title: Text(business['address_text']?.toString() ?? 'No address')),
        ListTile(leading: const Icon(Icons.email), title: Text(context.read<AuthProvider>().user?.email ?? '')),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _showEditBusiness(context, provider),
          icon: const Icon(Icons.edit),
          label: const Text('EDIT BUSINESS'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => context.read<AuthProvider>().logout(),
          icon: const Icon(Icons.logout),
          label: const Text('LOG OUT'),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 155,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label),
        ]),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inbox_rounded, size: 56, color: Colors.white38),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
      ]),
    ),
  );
}

Widget _bookingTile(Map<String, dynamic> booking) {
  final start = DateTime.tryParse(booking['start_at']?.toString() ?? '')?.toLocal();
  final startText = start == null
      ? 'Booking'
      : '${start.day}/${start.month}/${start.year} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  return Card(
    child: ListTile(
      leading: const Icon(Icons.event_available_rounded),
      title: Text(startText),
      subtitle: Text('Port ${booking['charger_port_id']}'),
      trailing: Chip(label: Text(booking['status']?.toString() ?? 'unknown')),
    ),
  );
}

Future<void> _showAddCharger(BuildContext context, BusinessProvider provider) async {
  final name = TextEditingController();
  final power = TextEditingController(text: '60');
  final lat = TextEditingController(text: provider.business?['latitude']?.toString() ?? '');
  final lng = TextEditingController(text: provider.business?['longitude']?.toString() ?? '');
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add charger'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: power, decoration: const InputDecoration(labelText: 'Power (kW)'), keyboardType: TextInputType.number),
        TextField(controller: lat, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number),
        TextField(controller: lng, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SAVE')),
      ],
    ),
  );
  if (accepted == true && context.mounted) {
    final powerKw = double.tryParse(power.text);
    final latitude = double.tryParse(lat.text);
    final longitude = double.tryParse(lng.text);
    if (name.text.trim().isEmpty || powerKw == null || latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a name, valid power, latitude, and longitude.')));
      return;
    }
    await provider.createCharger(
      name: name.text.trim(),
      chargerType: 'public',
      powerKw: powerKw,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

Future<void> _showAddPort(BuildContext context, BusinessProvider provider, Map<String, dynamic> charger) async {
  final number = TextEditingController(text: '${((charger['ports'] as List?)?.length ?? 0) + 1}');
  final power = TextEditingController(text: '60');
  int connector = 1;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: const Text('Add port'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(
          initialValue: connector,
          decoration: const InputDecoration(labelText: 'Connector'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('CCS2')),
            DropdownMenuItem(value: 2, child: Text('Type 2')),
            DropdownMenuItem(value: 3, child: Text('CHAdeMO')),
            DropdownMenuItem(value: 4, child: Text('Bharat AC')),
            DropdownMenuItem(value: 5, child: Text('Bharat DC')),
          ],
          onChanged: (value) => setState(() => connector = value ?? 1),
        ),
        TextField(controller: number, decoration: const InputDecoration(labelText: 'Port number'), keyboardType: TextInputType.number),
        TextField(controller: power, decoration: const InputDecoration(labelText: 'Max power (kW)'), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SAVE')),
      ],
    )),
  );
  if (accepted == true) {
    await provider.createPort(
      chargerId: charger['id'].toString(),
      connectorTypeId: connector,
      portNumber: int.tryParse(number.text) ?? 1,
      maxPowerKw: double.tryParse(power.text) ?? 60,
    );
  }
}

Future<void> _showAvailability(BuildContext context, BusinessProvider provider, String portId) async {
  final start = TextEditingController(text: '09:00');
  final end = TextEditingController(text: '18:00');
  int day = DateTime.now().weekday - 1;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: const Text('Create availability window'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(
          initialValue: day,
          decoration: const InputDecoration(labelText: 'Day'),
          items: List.generate(7, (index) => DropdownMenuItem(value: index, child: Text(const ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][index]))),
          onChanged: (value) => setState(() => day = value ?? day),
        ),
        TextField(controller: start, decoration: const InputDecoration(labelText: 'Start (HH:MM)')),
        TextField(controller: end, decoration: const InputDecoration(labelText: 'End (HH:MM)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SAVE')),
      ],
    )),
  );
  if (accepted == true) {
    await provider.createAvailability(
      portId: portId,
      dayOfWeek: day,
      startTime: start.text,
      endTime: end.text,
    );
  }
}

Future<void> _showEditBusiness(BuildContext context, BusinessProvider provider) async {
  final current = provider.business!;
  final name = TextEditingController(text: current['name']?.toString());
  final category = TextEditingController(text: current['category']?.toString());
  final address = TextEditingController(text: current['address_text']?.toString());
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit business'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SAVE')),
      ],
    ),
  );
  if (accepted == true) {
    await provider.updateBusiness(
      name: name.text.trim(),
      category: category.text.trim(),
      address: address.text.trim(),
    );
  }
}
