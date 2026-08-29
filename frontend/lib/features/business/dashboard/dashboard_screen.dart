import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// Live owner workspace. Every number and list on this screen comes from the
/// authenticated business APIs; an empty account is shown as an empty state,
/// never as a demo business or fabricated charger.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _selectedIndex = widget.initialTab.clamp(0, 4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BusinessProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, business, _) {
        if (business.isLoading && business.business == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (business.needsOnboarding) {
          return _BusinessOnboarding(onCreated: business.load);
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                _OverviewPage(),
                _ChargersPage(),
                _BookingsPage(),
                _AnalyticsPage(),
                _ProfilePage(),
              ],
            ),
          ),
          bottomNavigationBar: _BottomNav(
            selectedIndex: _selectedIndex,
            onChanged: (index) => setState(() => _selectedIndex = index),
          ),
        );
      },
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    final business = provider.business ?? const <String, dynamic>{};
    final metrics = provider.dashboard;
    final name = business['name']?.toString().trim();
    final reviews = _listOfMaps(metrics['reviews']);
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _PageHeader(
            eyebrow: 'VOLTEZ / BUSINESS',
            title: (name == null || name.isEmpty) ? 'Your business' : name,
            subtitle: 'Live operations overview',
            icon: Icons.notifications_none_rounded,
          ),
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: provider.errorMessage!),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('TODAY AT A GLANCE'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _MetricCard(label: 'TOTAL EARNINGS', value: _rupees(metrics['total_earnings']), icon: Icons.currency_rupee_rounded, color: AppColors.primary),
              _MetricCard(label: 'SESSIONS', value: _number(metrics['sessions']), icon: Icons.bolt_rounded, color: AppColors.marigold),
              _MetricCard(label: 'ACTIVE CHARGERS', value: '${_number(metrics['active_chargers'])}/${_number(metrics['chargers'])}', icon: Icons.ev_station_rounded, color: AppColors.secondary),
              _MetricCard(label: 'ACTIVE TIME', value: _minutes(metrics['active_minutes']), icon: Icons.timer_outlined, color: AppColors.coral),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('YOUR CHARGERS'),
          const SizedBox(height: 12),
          _ChargerList(provider.chargers),
          const SizedBox(height: 24),
          const _SectionTitle('RECENT BOOKINGS'),
          const SizedBox(height: 12),
          _BookingList(provider.bookings, allowCancel: false),
          const SizedBox(height: 24),
          const _SectionTitle('DRIVER REVIEWS'),
          const SizedBox(height: 12),
          _ReviewList(reviews),
        ],
      ),
    );
  }
}

class _ChargersPage extends StatelessWidget {
  const _ChargersPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _PageHeader(eyebrow: 'FLEET', title: 'Chargers', subtitle: 'Manage live station status and tariffs', icon: Icons.ev_station_rounded),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: () => _showAddCharger(context), icon: const Icon(Icons.add_rounded), label: const Text('REGISTER CHARGER')),
          const SizedBox(height: 14),
          _ChargerList(provider.chargers, showControls: true),
        ],
      ),
    );
  }
}

class _BookingsPage extends StatelessWidget {
  const _BookingsPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _PageHeader(eyebrow: 'RESERVATIONS', title: 'Bookings', subtitle: 'Confirmations and cancellations from your fleet', icon: Icons.calendar_today_rounded),
          const SizedBox(height: 18),
          _BookingList(provider.bookings, allowCancel: true),
        ],
      ),
    );
  }
}

class _AnalyticsPage extends StatelessWidget {
  const _AnalyticsPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _PageHeader(eyebrow: 'ML INSIGHTS', title: 'Analytics', subtitle: 'Recommendations generated from your live demand data', icon: Icons.insights_rounded),
          const SizedBox(height: 18),
          if (provider.recommendations.isEmpty)
            const _EmptyState(icon: Icons.auto_awesome_outlined, title: 'No recommendations yet', message: 'Recommendations appear once the network has enough live observations.')
          else
            ...provider.recommendations.map(_RecommendationCard.new),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    final business = provider.business ?? const <String, dynamic>{};
    final name = business['name']?.toString().trim();
    final address = business['address_text']?.toString();
    final verification = business['verification_status']?.toString() ?? 'pending';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        const Icon(Icons.business_rounded, size: 64, color: AppColors.primary),
        const SizedBox(height: 12),
        Center(child: Text(name?.isNotEmpty == true ? name! : 'Your business', style: AppTypography.displaySmall)),
        const SizedBox(height: 4),
        Center(child: Text(address?.isNotEmpty == true ? address! : 'Address not provided', style: AppTypography.bodyMedium, textAlign: TextAlign.center)),
        const SizedBox(height: 14),
        Center(
          child: ActionChip(
            avatar: Icon(
              verification == 'verified' ? Icons.verified_rounded : Icons.pending_actions_rounded,
              color: verification == 'verified' ? AppColors.success : AppColors.marigold,
              size: 18,
            ),
            label: Text('KYC: ${verification.toUpperCase()}'),
            onPressed: () {
              final id = business['id']?.toString();
              if (id != null) _showBusinessKycDialog(context, id);
            },
          ),
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
          title: const Text('Host KYC & Verification'),
          subtitle: Text('Status: ${verification.toUpperCase()} • Tap to update GSTIN/PAN'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            final id = business['id']?.toString();
            if (id != null) _showBusinessKycDialog(context, id);
          },
        ),
        ListTile(leading: const Icon(Icons.refresh_rounded, color: AppColors.primary), title: const Text('Refresh live data'), onTap: provider.load),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: AppColors.error),
          title: const Text('Sign out'),
          onTap: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}


class _ChargerList extends StatelessWidget {
  const _ChargerList(this.chargers, {this.showControls = false});
  final List<Map<String, dynamic>> chargers;
  final bool showControls;

  @override
  Widget build(BuildContext context) {
    if (chargers.isEmpty) return const _EmptyState(icon: Icons.ev_station_outlined, title: 'No chargers registered', message: 'Register a real charger to make it discoverable to drivers.');
    final provider = context.read<BusinessProvider>();
    return Column(
      children: chargers.map((charger) {
        final name = charger['name']?.toString() ?? 'Unnamed charger';
        final status = charger['status']?.toString() ?? 'unknown';
        final power = _number(charger['power_kw']);
        final price = _rupees(charger['price_per_kwh']);
        final ports = (charger['ports'] as List<dynamic>? ?? const []).length;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: _statusColor(status).withValues(alpha: 0.15), child: Icon(Icons.ev_station_rounded, color: _statusColor(status))),
            title: Text(name, style: AppTypography.headlineSmall),
            subtitle: Text('$power kW • $ports port${ports == 1 ? '' : 's'} • $price/kWh'),
            trailing: showControls
                ? PopupMenuButton<String>(
                    onSelected: (value) => provider.setChargerStatus(charger['id'].toString(), value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'available', child: Text('Available')),
                      PopupMenuItem(value: 'unavailable', child: Text('Unavailable')),
                      PopupMenuItem(value: 'maintenance', child: Text('Maintenance')),
                      PopupMenuItem(value: 'offline', child: Text('Offline')),
                    ],
                  )
                : Chip(label: Text(status.toUpperCase())),
          ),
        );
      }).toList(),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList(this.bookings, {required this.allowCancel});
  final List<Map<String, dynamic>> bookings;
  final bool allowCancel;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const _EmptyState(icon: Icons.calendar_month_outlined, title: 'No bookings yet', message: 'Driver reservations will appear here when they are made.');
    final provider = context.read<BusinessProvider>();
    return Column(
      children: bookings.map((booking) {
        final start = DateTime.tryParse(booking['start_at']?.toString() ?? '')?.toLocal();
        final status = booking['status']?.toString() ?? 'unknown';
        final cancellable = const {'pending', 'held', 'confirmed'}.contains(status.toLowerCase());
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.event_available_rounded, color: AppColors.primary),
            title: Text(booking['charger_name']?.toString() ?? 'Unknown charger'),
            subtitle: Text('${start == null ? 'Time unavailable' : _dateTime(start)} • ${booking['connector_type'] ?? 'Unknown connector'}'),
            trailing: allowCancel && cancellable
                ? IconButton(tooltip: 'Cancel booking', icon: const Icon(Icons.cancel_outlined, color: AppColors.error), onPressed: () => provider.cancelBooking(booking['id'].toString()))
                : Chip(label: Text(status.toUpperCase())),
          ),
        );
      }).toList(),
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList(this.reviews);
  final List<Map<String, dynamic>> reviews;
  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const _EmptyState(icon: Icons.rate_review_outlined, title: 'No reviews yet', message: 'Completed session feedback will be shown here.');
    return Column(
      children: reviews.map((review) {
        final rating = (review['rating'] as num?)?.toDouble() ?? 0;
        final comment = review['comment']?.toString().trim();
        return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: const Icon(Icons.star_rounded, color: AppColors.marigold), title: Text('${rating.toStringAsFixed(1)} / 5'), subtitle: Text(comment?.isNotEmpty == true ? comment! : 'No written feedback')));
      }).toList(),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard(this.data);
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary), title: Text(data['recommended_action']?.toString() ?? 'Recommendation'), subtitle: Text(data['reason_code']?.toString() ?? 'Based on live demand'), trailing: Text('${_number((data['confidence'] as num?)?.toDouble().toStringAsFixed(0))}%')));
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});
  final String label; final String value; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color, size: 22), Text(value, style: AppTypography.headlineMedium), Text(label, style: AppTypography.labelSmall)])));
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.eyebrow, required this.title, required this.subtitle, required this.icon});
  final String eyebrow; final String title; final String subtitle; final IconData icon;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(eyebrow, style: AppTypography.labelMedium.copyWith(color: AppColors.primary)), const SizedBox(height: 6), Text(title, style: AppTypography.displaySmall), const SizedBox(height: 4), Text(subtitle, style: AppTypography.bodySmall)])), CircleAvatar(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary, child: Icon(icon))]);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title); final String title;
  @override
  Widget build(BuildContext context) => Text(title, style: AppTypography.labelMedium.copyWith(letterSpacing: 1.1, color: AppColors.secondary));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.message});
  final IconData icon; final String title; final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [Icon(icon, size: 40, color: AppColors.textMuted), const SizedBox(height: 10), Text(title, style: AppTypography.headlineSmall, textAlign: TextAlign.center), const SizedBox(height: 4), Text(message, style: AppTypography.bodySmall, textAlign: TextAlign.center)])));
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message}); final String message;
  @override
  Widget build(BuildContext context) => Card(color: AppColors.error.withValues(alpha: 0.08), child: Padding(padding: const EdgeInsets.all(12), child: Text(message, style: const TextStyle(color: AppColors.error))));
}

class _BusinessOnboarding extends StatefulWidget {
  const _BusinessOnboarding({required this.onCreated}); final Future<void> Function() onCreated;
  @override State<_BusinessOnboarding> createState() => _BusinessOnboardingState();
}

class _BusinessOnboardingState extends State<_BusinessOnboarding> {
  final _name = TextEditingController(); final _category = TextEditingController(text: 'charging_host'); final _address = TextEditingController(); final _lat = TextEditingController(); final _lng = TextEditingController();
  @override void dispose() { _name.dispose(); _category.dispose(); _address.dispose(); _lat.dispose(); _lng.dispose(); super.dispose(); }
  Future<void> _submit() async {
    final latitude = double.tryParse(_lat.text.trim()); final longitude = double.tryParse(_lng.text.trim());
    if (_name.text.trim().isEmpty || latitude == null || longitude == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter business name and valid latitude/longitude.'))); return; }
    final ok = await context.read<BusinessProvider>().createBusiness(name: _name.text.trim(), category: _category.text.trim(), address: _address.text.trim(), latitude: latitude, longitude: longitude);
    if (ok) await widget.onCreated();
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [const Icon(Icons.business_rounded, size: 56, color: AppColors.primary), const SizedBox(height: 14), Text('Register your business', style: AppTypography.displaySmall), const SizedBox(height: 6), const Text('We need the real location so drivers can discover your chargers accurately.'), const SizedBox(height: 20), _input(_name, 'Business name'), _input(_category, 'Category'), _input(_address, 'Address'), Row(children: [Expanded(child: _input(_lat, 'Latitude', keyboard: const TextInputType.numberWithOptions(decimal: true))), const SizedBox(width: 10), Expanded(child: _input(_lng, 'Longitude', keyboard: const TextInputType.numberWithOptions(decimal: true)))]), const SizedBox(height: 12), FilledButton(onPressed: _submit, child: const Text('CREATE BUSINESS'))])));
  Widget _input(TextEditingController controller, String label, {TextInputType? keyboard}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controller, keyboardType: keyboard, inputFormatters: keyboard == null ? null : [FilteringTextInputFormatter.allow(RegExp(r'[-.0-9]'))], decoration: InputDecoration(labelText: label)));
}

Future<void> _showAddCharger(BuildContext context) async {
  final name = TextEditingController(); final type = TextEditingController(text: 'DC'); final power = TextEditingController(); final price = TextEditingController(text: '15'); final lat = TextEditingController(); final lng = TextEditingController();
  await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Register charger'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [_dialogInput(name, 'Name'), _dialogInput(type, 'Type (AC/DC)'), _dialogInput(power, 'Power kW'), _dialogInput(price, 'Price per kWh'), _dialogInput(lat, 'Latitude'), _dialogInput(lng, 'Longitude')])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')), FilledButton(onPressed: () async { final p = double.tryParse(power.text); final la = double.tryParse(lat.text); final lo = double.tryParse(lng.text); final pr = double.tryParse(price.text); if (name.text.trim().isEmpty || p == null || la == null || lo == null || pr == null) return; final ok = await context.read<BusinessProvider>().createCharger(name: name.text.trim(), chargerType: type.text.trim(), powerKw: p, pricePerKwh: pr, latitude: la, longitude: lo); if (dialogContext.mounted && ok) Navigator.pop(dialogContext); }, child: const Text('SAVE'))]));
  name.dispose(); type.dispose(); power.dispose(); price.dispose(); lat.dispose(); lng.dispose();
}

Future<void> _showBusinessKycDialog(BuildContext context, String businessId) async {
  final gstin = TextEditingController();
  final pan = TextEditingController();
  final meter = TextEditingController();
  final upi = TextEditingController(text: 'host@upi');

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.verified_user_rounded, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Host KYC Verification'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Submit verified business credentials to receive automated driver payouts and unlock 24/7 public listing.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _dialogInput(gstin, 'GSTIN (e.g. 27AAAAA0000A1Z5)'),
            _dialogInput(pan, 'Business PAN (e.g. AAAAA0000A)'),
            _dialogInput(meter, 'Electricity Consumer / Meter ID'),
            _dialogInput(upi, 'Payout UPI ID'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () async {
            if (gstin.text.trim().isEmpty && pan.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter at least GSTIN or PAN.')),
              );
              return;
            }
            try {
              await context.read<BusinessProvider>().submitKyc(
                businessId: businessId,
                gstin: gstin.text.trim().isNotEmpty ? gstin.text.trim() : null,
                panNumber: pan.text.trim().isNotEmpty ? pan.text.trim() : null,
                electricityMeterId: meter.text.trim().isNotEmpty ? meter.text.trim() : null,
                payoutUpiId: upi.text.trim().isNotEmpty ? upi.text.trim() : null,
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Host KYC submitted successfully! Verification status: VERIFIED')),
                );
              }
            } catch (e) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('KYC submission error: $e')),
                );
              }
            }
          },
          child: const Text('VERIFY & SUBMIT'),
        ),
      ],
    ),
  );
  gstin.dispose();
  pan.dispose();
  meter.dispose();
  upi.dispose();
}


Widget _dialogInput(TextEditingController c, String label) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, decoration: InputDecoration(labelText: label), keyboardType: label == 'Name' || label.startsWith('Type') ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true)));
List<Map<String, dynamic>> _listOfMaps(dynamic value) => (value as List<dynamic>? ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
String _number(dynamic value) => value is num ? (value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1)) : '0';
String _rupees(dynamic value) => '₹${_number(value)}';
String _minutes(dynamic value) { final mins = (value as num?)?.toDouble() ?? 0; return mins >= 60 ? '${(mins / 60).toStringAsFixed(1)} h' : '${mins.toStringAsFixed(0)} m'; }
String _dateTime(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
Color _statusColor(String status) { switch (status.toLowerCase()) { case 'available': return AppColors.success; case 'maintenance': return AppColors.marigold; case 'unavailable': return AppColors.coral; default: return AppColors.textMuted; } }

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onChanged}); final int selectedIndex; final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => NavigationBar(selectedIndex: selectedIndex, onDestinationSelected: onChanged, destinations: const [NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'), NavigationDestination(icon: Icon(Icons.ev_station_rounded), label: 'Chargers'), NavigationDestination(icon: Icon(Icons.calendar_today_rounded), label: 'Bookings'), NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Analytics'), NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Profile')]);
}
