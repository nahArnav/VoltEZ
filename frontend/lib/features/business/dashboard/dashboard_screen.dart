import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
              _MetricCard(
                label: 'TOTAL EARNINGS',
                value: _rupees(metrics['total_earnings']),
                icon: Icons.currency_rupee_rounded,
                color: AppColors.primary,
              ),
              _MetricCard(
                label: 'SESSIONS',
                value: _number(metrics['sessions']),
                icon: Icons.bolt_rounded,
                color: AppColors.marigold,
              ),
              _MetricCard(
                label: 'ACTIVE CHARGERS',
                value:
                    '${_number(metrics['active_chargers'])}/${_number(metrics['chargers'])}',
                icon: Icons.ev_station_rounded,
                color: AppColors.secondary,
              ),
              _MetricCard(
                label: 'ACTIVE TIME',
                value: _minutes(metrics['active_minutes']),
                icon: Icons.timer_outlined,
                color: AppColors.coral,
              ),
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
          const _PageHeader(
            eyebrow: 'FLEET',
            title: 'Chargers',
            subtitle: 'Manage live station status and tariffs',
            icon: Icons.ev_station_rounded,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _showAddCharger(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('REGISTER CHARGER'),
          ),
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
          const _PageHeader(
            eyebrow: 'RESERVATIONS',
            title: 'Bookings',
            subtitle: 'Confirmations and cancellations from your fleet',
            icon: Icons.calendar_today_rounded,
          ),
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
          const _PageHeader(
            eyebrow: 'ML INSIGHTS',
            title: 'Analytics',
            subtitle: 'Recommendations generated from your live demand data',
            icon: Icons.insights_rounded,
          ),
          const SizedBox(height: 18),
          if (provider.recommendations.isEmpty)
            const _EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'No recommendations yet',
              message:
                  'Recommendations appear once the network has enough live observations.',
            )
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
    final verification =
        business['verification_status']?.toString() ?? 'pending';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        const Icon(Icons.business_rounded, size: 64, color: AppColors.primary),
        const SizedBox(height: 12),
        Center(
          child: Text(
            name?.isNotEmpty == true ? name! : 'Your business',
            style: AppTypography.displaySmall,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            address?.isNotEmpty == true ? address! : 'Address not provided',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: ActionChip(
            avatar: Icon(
              verification == 'verified'
                  ? Icons.verified_rounded
                  : Icons.pending_actions_rounded,
              color: verification == 'verified'
                  ? AppColors.success
                  : AppColors.marigold,
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
          leading: const Icon(
            Icons.verified_user_outlined,
            color: AppColors.primary,
          ),
          title: const Text('Host KYC & Verification'),
          subtitle: Text(
            'Status: ${verification.toUpperCase()} • Tap to update GSTIN/PAN',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            final id = business['id']?.toString();
            if (id != null) _showBusinessKycDialog(context, id);
          },
        ),
        ListTile(
          leading: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          title: const Text('Refresh live data'),
          onTap: provider.load,
        ),
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
    if (chargers.isEmpty) {
      return const _EmptyState(
        icon: Icons.ev_station_outlined,
        title: 'No chargers registered',
        message: 'Register a real charger to make it discoverable to drivers.',
      );
    }
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
            leading: CircleAvatar(
              backgroundColor: _statusColor(status).withValues(alpha: 0.15),
              child: Icon(
                Icons.ev_station_rounded,
                color: _statusColor(status),
              ),
            ),
            title: Text(name, style: AppTypography.headlineSmall),
            subtitle: Text(
              '$power kW • $ports port${ports == 1 ? '' : 's'} • $price/kWh',
            ),
            trailing: showControls
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'add_port') {
                        _showAddPort(context, charger);
                      } else if (value == 'availability') {
                        _showAvailability(context, charger);
                      } else if (value == 'tariff') {
                        _showEditTariff(context, charger);
                      } else {
                        provider.setChargerStatus(
                          charger['id'].toString(),
                          value,
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'add_port',
                        child: Text('Add connector port'),
                      ),
                      PopupMenuItem(
                        value: 'availability',
                        child: Text('Set availability'),
                      ),
                      PopupMenuItem(
                        value: 'tariff',
                        child: Text('Update base tariff'),
                      ),
                      PopupMenuItem(
                        value: 'available',
                        child: Text('Available'),
                      ),
                      PopupMenuItem(
                        value: 'unavailable',
                        child: Text('Unavailable'),
                      ),
                      PopupMenuItem(
                        value: 'maintenance',
                        child: Text('Maintenance'),
                      ),
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
    if (bookings.isEmpty) {
      return const _EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No bookings yet',
        message: 'Driver reservations will appear here when they are made.',
      );
    }
    final provider = context.read<BusinessProvider>();
    return Column(
      children: bookings.map((booking) {
        final start = DateTime.tryParse(
          booking['start_at']?.toString() ?? '',
        )?.toLocal();
        final status = booking['status']?.toString() ?? 'unknown';
        final cancellable = const {
          'pending',
          'held',
          'confirmed',
        }.contains(status.toLowerCase());
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(
              Icons.event_available_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              booking['charger_name']?.toString() ?? 'Unknown charger',
            ),
            subtitle: Text(
              '${start == null ? 'Time unavailable' : _dateTime(start)} • ${booking['connector_type'] ?? 'Unknown connector'}',
            ),
            trailing: allowCancel && cancellable
                ? IconButton(
                    tooltip: 'Cancel booking',
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: AppColors.error,
                    ),
                    onPressed: () =>
                        provider.cancelBooking(booking['id'].toString()),
                  )
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
    if (reviews.isEmpty) {
      return const _EmptyState(
        icon: Icons.rate_review_outlined,
        title: 'No reviews yet',
        message: 'Completed session feedback will be shown here.',
      );
    }
    return Column(
      children: reviews.map((review) {
        final rating = (review['rating'] as num?)?.toDouble() ?? 0;
        final comment = review['comment']?.toString().trim();
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.star_rounded, color: AppColors.marigold),
            title: Text('${rating.toStringAsFixed(1)} / 5'),
            subtitle: Text(
              comment?.isNotEmpty == true ? comment! : 'No written feedback',
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard(this.data);
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0;
    final percent = confidence <= 1 ? confidence * 100 : confidence;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.primary,
        ),
        title: Text(data['recommended_action']?.toString() ?? 'Recommendation'),
        subtitle: Text(
          data['reason_code']?.toString() ?? 'Based on live demand',
        ),
        trailing: Text('${percent.round()}%'),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Text(value, style: AppTypography.headlineMedium),
          Text(label, style: AppTypography.labelSmall),
        ],
      ),
    ),
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(title, style: AppTypography.displaySmall),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTypography.bodySmall),
          ],
        ),
      ),
      CircleAvatar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        child: Icon(icon),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: AppTypography.labelMedium.copyWith(
      letterSpacing: 1.1,
      color: AppColors.secondary,
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTypography.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.error.withValues(alpha: 0.08),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    ),
  );
}

class _BusinessOnboarding extends StatefulWidget {
  const _BusinessOnboarding({required this.onCreated});
  final Future<void> Function() onCreated;
  @override
  State<_BusinessOnboarding> createState() => _BusinessOnboardingState();
}

class _BusinessOnboardingState extends State<_BusinessOnboarding> {
  final _name = TextEditingController();
  final _category = TextEditingController(text: 'charging_host');
  final _address = TextEditingController();
  Timer? _addressSearchTimer;
  var _addressSearchToken = 0;
  var _addressSearching = false;
  List<_AddressSuggestion> _addressSuggestions = const [];
  double? _selectedLatitude;
  double? _selectedLongitude;
  @override
  void dispose() {
    _addressSearchTimer?.cancel();
    _name.dispose();
    _category.dispose();
    _address.dispose();
    super.dispose();
  }

  void _searchAddress(String value) {
    _addressSearchTimer?.cancel();
    final token = ++_addressSearchToken;
    setState(() {
      _selectedLatitude = null;
      _selectedLongitude = null;
      _addressSuggestions = const [];
      _addressSearching = value.trim().length >= 3;
    });
    if (value.trim().length < 3) return;
    _addressSearchTimer = Timer(const Duration(milliseconds: 350), () async {
      final suggestions = await _searchAddressSuggestions(value.trim());
      if (!mounted || token != _addressSearchToken) return;
      setState(() {
        _addressSuggestions = suggestions;
        _addressSearching = false;
      });
    });
  }

  Future<void> _useCurrentLocation() async {
    _addressSearchTimer?.cancel();
    _addressSearchToken++;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission was denied.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      setState(() {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
        _address.text = 'Current device location';
        _addressSuggestions = const [];
        _addressSearching = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read device location: $error')),
      );
    }
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _selectedLatitude == null ||
        _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a business name and select a verified address.'),
        ),
      );
      return;
    }
    final ok = await context.read<BusinessProvider>().createBusiness(
      name: _name.text.trim(),
      category: _category.text.trim(),
      address: _address.text.trim(),
      latitude: _selectedLatitude!,
      longitude: _selectedLongitude!,
    );
    if (ok) await widget.onCreated();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.business_rounded,
            size: 56,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          Text('Register your business', style: AppTypography.displaySmall),
          const SizedBox(height: 6),
          const Text(
            'We need the real location so drivers can discover your chargers accurately.',
          ),
          const SizedBox(height: 20),
          _input(_name, 'Business name'),
          _input(_category, 'Category'),
          TextField(
            controller: _address,
            onChanged: _searchAddress,
            decoration: InputDecoration(
              labelText: 'Search business address',
              hintText: 'Search a landmark, street, or business',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Use current location',
                icon: const Icon(Icons.my_location_rounded),
                onPressed: _useCurrentLocation,
              ),
            ),
          ),
          if (_addressSearching)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_addressSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: _addressSuggestions
                    .map(
                      (suggestion) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(
                          suggestion.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => setState(() {
                          _addressSearchTimer?.cancel();
                          _addressSearchToken++;
                          _selectedLatitude = suggestion.latitude;
                          _selectedLongitude = suggestion.longitude;
                          _address.text = suggestion.label;
                          _addressSuggestions = const [];
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (_selectedLatitude != null)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                'Location selected. Coordinates will be saved automatically.',
                style: TextStyle(fontSize: 12, color: AppColors.success),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submit,
            child: const Text('CREATE BUSINESS'),
          ),
        ],
      ),
    ),
  );
  Widget _input(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: keyboard == null
          ? null
          : [FilteringTextInputFormatter.allow(RegExp(r'[-.0-9]'))],
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class _AddressSuggestion {
  const _AddressSuggestion({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

Future<List<_AddressSuggestion>> _searchAddressSuggestions(String query) async {
  try {
    final locations = await locationFromAddress(query);
    final suggestions = <_AddressSuggestion>[];
    for (final location in locations.take(5)) {
      var label = query;
      try {
        final placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          label = [
            place.name,
            place.street,
            place.locality,
            place.administrativeArea,
          ]
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .join(', ');
        }
      } catch (_) {
        // Coordinates remain usable even when reverse labelling is unavailable.
      }
      suggestions.add(
        _AddressSuggestion(
          label: label,
          latitude: location.latitude,
          longitude: location.longitude,
        ),
      );
    }
    return suggestions;
  } catch (_) {
    return const [];
  }
}

Future<void> _showAddCharger(BuildContext context) async {
  final name = TextEditingController();
  final type = TextEditingController(text: 'DC');
  final power = TextEditingController();
  final price = TextEditingController();
  final location = TextEditingController();
  Timer? searchTimer;
  var searchToken = 0;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      var suggestions = <_AddressSuggestion>[];
      var searching = false;
      var saving = false;
      double? selectedLatitude;
      double? selectedLongitude;

      Future<void> search(String query, void Function(void Function()) setState) async {
        searchTimer?.cancel();
        final token = ++searchToken;
        if (query.trim().length < 3) {
          setState(() {
            suggestions = [];
            searching = false;
          });
          return;
        }
        searchTimer = Timer(const Duration(milliseconds: 350), () async {
          if (!dialogContext.mounted) return;
          setState(() => searching = true);
          final results = await _searchAddressSuggestions(query.trim());
          if (!dialogContext.mounted || token != searchToken) return;
          setState(() {
            suggestions = results;
            searching = false;
          });
        });
      }

      Future<void> useCurrentLocation(void Function(void Function()) setState) async {
        searchTimer?.cancel();
        searchToken++;
        try {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            throw StateError('Location permission was denied.');
          }
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          if (!dialogContext.mounted) return;
          selectedLatitude = position.latitude;
          selectedLongitude = position.longitude;
          location.text = 'Current device location';
          setState(() => suggestions = []);
        } catch (error) {
          if (dialogContext.mounted) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(content: Text('Could not read device location: $error')),
            );
          }
        }
      }

      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.ev_station_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Register charger',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.68,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogInput(name, 'Name'),
                  _dialogInput(type, 'Type (AC/DC)'),
                  _dialogInput(
                    power,
                    'Power kW',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  _dialogInput(
                    price,
                    'Base price per kWh (INR)',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'VoltEZ applies a bounded peak/off-peak multiplier using live demand and availability signals.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  TextField(
                    controller: location,
                    onChanged: (value) {
                      selectedLatitude = null;
                      selectedLongitude = null;
                      search(value, setState);
                    },
                    decoration: InputDecoration(
                      labelText: 'Search charger address',
                      hintText: 'Search a landmark, street, or business',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Use current location',
                        icon: const Icon(Icons.my_location_rounded),
                        onPressed: () => useCurrentLocation(setState),
                      ),
                    ),
                  ),
                  if (searching) const LinearProgressIndicator(minHeight: 2),
                  if (suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: suggestions
                            .map(
                              (suggestion) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on_outlined),
                                title: Text(
                                  suggestion.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  searchTimer?.cancel();
                                  searchToken++;
                                  selectedLatitude = suggestion.latitude;
                                  selectedLongitude = suggestion.longitude;
                                  location.text = suggestion.label;
                                  setState(() => suggestions = []);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (selectedLatitude != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Location selected. Coordinates will be saved automatically.',
                        style: TextStyle(fontSize: 12, color: AppColors.success),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final p = double.tryParse(power.text.trim());
                      final pr = double.tryParse(price.text.trim());
                      if (name.text.trim().isEmpty || p == null || p <= 0 || pr == null || pr <= 0) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Enter a name, positive power, and base tariff.')),
                        );
                        return;
                      }
                      if (selectedLatitude == null || selectedLongitude == null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Select the charger address from the suggestions first.')),
                        );
                        return;
                      }
                      setState(() => saving = true);
                      final ok = await context.read<BusinessProvider>().createCharger(
                        name: name.text.trim(),
                        chargerType: type.text.trim(),
                        powerKw: p,
                        pricePerKwh: pr,
                        latitude: selectedLatitude!,
                        longitude: selectedLongitude!,
                        addressText: location.text.trim(),
                      );
                      if (!dialogContext.mounted) return;
                      if (ok) {
                        Navigator.pop(dialogContext);
                      } else {
                        final error = context
                                .read<BusinessProvider>()
                                .errorMessage ??
                            'Charger could not be registered. Check your session and try again.';
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                        setState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'SAVING…' : 'SAVE'),
            ),
          ],
        ),
      );
    },
  );
  searchTimer?.cancel();
  name.dispose();
  type.dispose();
  power.dispose();
  price.dispose();
  location.dispose();
}

Future<void> _showAddPort(
  BuildContext context,
  Map<String, dynamic> charger,
) async {
  final portNumber = TextEditingController();
  final power = TextEditingController();
  var connectorId = 1;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Add port to ${charger['name'] ?? 'charger'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: connectorId,
                decoration: const InputDecoration(labelText: 'Connector'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('CCS2')),
                  DropdownMenuItem(value: 2, child: Text('Type 2')),
                  DropdownMenuItem(value: 3, child: Text('CHAdeMO')),
                  DropdownMenuItem(value: 4, child: Text('Bharat AC-001')),
                  DropdownMenuItem(value: 5, child: Text('Bharat DC-001')),
                  DropdownMenuItem(value: 6, child: Text('Type 1')),
                  DropdownMenuItem(value: 7, child: Text('GB/T')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => connectorId = value);
                },
              ),
              _dialogInput(
                portNumber,
                'Port number',
                keyboard: TextInputType.number,
              ),
              _dialogInput(
                power,
                'Maximum power (kW)',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 6),
              const Text(
                'After adding the port, use “Set availability” to publish host-approved time windows.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
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
              final number = int.tryParse(portNumber.text.trim());
              final maxPower = double.tryParse(power.text.trim());
              if (number == null ||
                  number <= 0 ||
                  maxPower == null ||
                  maxPower <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid port number and power.'),
                  ),
                );
                return;
              }
              final ok = await context.read<BusinessProvider>().createPort(
                chargerId: charger['id'].toString(),
                connectorTypeId: connectorId,
                portNumber: number,
                maxPowerKw: maxPower,
              );
              if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('ADD PORT'),
          ),
        ],
      ),
    ),
  );
  portNumber.dispose();
  power.dispose();
}

Future<void> _showEditTariff(
  BuildContext context,
  Map<String, dynamic> charger,
) async {
  final price = TextEditingController(
    text: charger['price_per_kwh']?.toString() ?? '',
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Update base tariff · ${charger['name'] ?? ''}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogInput(
              price,
              'Base price per kWh (INR)',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            const Text(
              'This is the owner-controlled base. VoltEZ applies a bounded live multiplier per slot.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
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
            final value = double.tryParse(price.text.trim());
            if (value == null || value <= 0) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Enter a positive base tariff.')),
              );
              return;
            }
            final ok = await context.read<BusinessProvider>().updateChargerTariff(
              chargerId: charger['id'].toString(),
              pricePerKwh: value,
            );
            if (!dialogContext.mounted) return;
            if (ok) {
              Navigator.pop(dialogContext);
            } else {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text(
                    context.read<BusinessProvider>().errorMessage ??
                        'Could not update tariff.',
                  ),
                ),
              );
            }
          },
          child: const Text('SAVE TARIFF'),
        ),
      ],
    ),
  );
  price.dispose();
}

Future<void> _showAvailability(
  BuildContext context,
  Map<String, dynamic> charger,
) async {
  final rawPorts = (charger['ports'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((port) => Map<String, dynamic>.from(port))
      .toList();
  if (rawPorts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add a connector port before publishing availability.'),
      ),
    );
    return;
  }
  final start = TextEditingController(text: '08:00');
  final end = TextEditingController(text: '22:00');
  var day = DateTime.now().weekday - 1;
  var portId = rawPorts.first['id'].toString();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Publish availability · ${charger['name'] ?? ''}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: portId,
                decoration: const InputDecoration(labelText: 'Port'),
                items: [
                  for (final port in rawPorts)
                    DropdownMenuItem(
                      value: port['id'].toString(),
                      child: Text('Port ${port['port_number'] ?? ''}'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => portId = value);
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: day,
                decoration: const InputDecoration(labelText: 'Day'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Monday')),
                  DropdownMenuItem(value: 1, child: Text('Tuesday')),
                  DropdownMenuItem(value: 2, child: Text('Wednesday')),
                  DropdownMenuItem(value: 3, child: Text('Thursday')),
                  DropdownMenuItem(value: 4, child: Text('Friday')),
                  DropdownMenuItem(value: 5, child: Text('Saturday')),
                  DropdownMenuItem(value: 6, child: Text('Sunday')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => day = value);
                },
              ),
              _dialogInput(start, 'Start time (HH:MM)'),
              _dialogInput(end, 'End time (HH:MM)'),
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
              final validTime = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
              if (!validTime.hasMatch(start.text.trim()) ||
                  !validTime.hasMatch(end.text.trim()) ||
                  start.text.trim().compareTo(end.text.trim()) >= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Use valid times and ensure end is after start.',
                    ),
                  ),
                );
                return;
              }
              final ok = await context
                  .read<BusinessProvider>()
                  .createAvailability(
                    portId: portId,
                    dayOfWeek: day,
                    startTime: start.text.trim(),
                    endTime: end.text.trim(),
                  );
              if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('PUBLISH'),
          ),
        ],
      ),
    ),
  );
  start.dispose();
  end.dispose();
}

Future<void> _showBusinessKycDialog(
  BuildContext context,
  String businessId,
) async {
  final gstin = TextEditingController();
  final pan = TextEditingController();
  final meter = TextEditingController();
  final upi = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.verified_user_rounded, color: AppColors.primary),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Host KYC Verification',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),

      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.58,
        ),
        child: SingleChildScrollView(
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
                const SnackBar(
                  content: Text('Please enter at least GSTIN or PAN.'),
                ),
              );
              return;
            }
            try {
              final ok = await context.read<BusinessProvider>().submitKyc(
                businessId: businessId,
                gstin: gstin.text.trim().isNotEmpty ? gstin.text.trim() : null,
                panNumber: pan.text.trim().isNotEmpty ? pan.text.trim() : null,
                electricityMeterId: meter.text.trim().isNotEmpty
                    ? meter.text.trim()
                    : null,
                payoutUpiId: upi.text.trim().isNotEmpty
                    ? upi.text.trim()
                    : null,
              );
              if (dialogContext.mounted && ok) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Host KYC submitted. Verification status: PENDING REVIEW',
                    ),
                  ),
                );
              } else if (dialogContext.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('KYC submission failed. Please retry.'),
                  ),
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

Widget _dialogInput(
  TextEditingController c,
  String label, {
  TextInputType keyboard = TextInputType.text,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextField(
    controller: c,
    decoration: InputDecoration(labelText: label),
    keyboardType: keyboard,
  ),
);
List<Map<String, dynamic>> _listOfMaps(dynamic value) =>
    (value as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
String _number(dynamic value) => value is num
    ? (value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1))
    : '0';
String _rupees(dynamic value) => '₹${_number(value)}';
String _minutes(dynamic value) {
  final mins = (value as num?)?.toDouble() ?? 0;
  return mins >= 60
      ? '${(mins / 60).toStringAsFixed(1)} h'
      : '${mins.toStringAsFixed(0)} m';
}

String _dateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'available':
      return AppColors.success;
    case 'maintenance':
      return AppColors.marigold;
    case 'unavailable':
      return AppColors.coral;
    default:
      return AppColors.textMuted;
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onChanged});
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onChanged,
    destinations: const [
      NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
      NavigationDestination(
        icon: Icon(Icons.ev_station_rounded),
        label: 'Chargers',
      ),
      NavigationDestination(
        icon: Icon(Icons.calendar_today_rounded),
        label: 'Bookings',
      ),
      NavigationDestination(
        icon: Icon(Icons.insights_rounded),
        label: 'Analytics',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        label: 'Profile',
      ),
    ],
  );
}
