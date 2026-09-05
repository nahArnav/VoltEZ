import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/charger_discovery_provider.dart';
import '../../../core/providers/route_planner_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/network/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../history/booking_history_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _selectedNav = 0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final discovery = context.read<ChargerDiscoveryProvider>();
      if (discovery.allChargers.isEmpty && !discovery.chargersLoading) {
        discovery.init();
      }
      context.read<RoutePlannerProvider>().loadVehicles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _selectedNav == 0
            ? _buildHomeTab()
            : _selectedNav == 2
            ? _buildChargersTab()
            : _selectedNav == 3
            ? const DriverHistoryScreen()
            : _selectedNav == 4
            ? _buildProfileTab()
            : _buildPlaceholderTab(),
      ),
      bottomNavigationBar: AppBottomNavBar(
        items: AppBottomNavBar.driverItems,
        selectedIndex: _selectedNav,
        onChanged: (index) {
          if (index == 1) {
            context.go('/driver/map');
            return;
          }
          setState(() => _selectedNav = index);
        },
      ),
    );
  }

  // ─── HOME TAB ───
  Widget _buildHomeTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeader(),
              const SizedBox(height: 16),

              // Active session banner
              Consumer<SessionProvider>(
                builder: (context, session, _) {
                  if (session.phase != SessionPhase.charging &&
                      session.phase != SessionPhase.checkedIn) {
                    return const SizedBox.shrink();
                  }
                  return _buildActiveSessionBanner(session);
                },
              ),

              const SizedBox(height: 8),
              _buildBatteryCard(),
              const SizedBox(height: 24),
              _buildSearchBar(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildSponsorsCard(),
              const SizedBox(height: 28),
              _buildSectionHeader('NEARBY CHARGERS', 'See all'),
              const SizedBox(height: 14),
              _buildNearbyChargers(),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  // ─── Active Session Banner ───
  Widget _buildActiveSessionBanner(SessionProvider session) {
    final data = session.sessionData;
    final soc = data?.batteryPercent ?? 0;
    final isCharging = session.phase == SessionPhase.charging;

    return GestureDetector(
      onTap: () => context.go('/driver/session'),
      child: GlassCard(
        accentColor: AppColors.primary,
        padding: const EdgeInsets.all(16),
        borderRadius: 18,
        child: Row(
          children: [
            // Pulsing indicator
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCharging ? Icons.bolt_rounded : Icons.ev_station_rounded,
                color: AppColors.onPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCharging ? 'CHARGING NOW' : 'CHECKED IN',
                    style: TextStyle(
                      color: AppColors.onPrimary.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data?.chargerName ?? 'Charger',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                if (isCharging)
                  Text(
                    '${soc.round()}%',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.onPrimary.withValues(alpha: 0.7),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VOLTEZ / USER',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text('${_greeting()},', style: AppTypography.bodyMedium),
              const SizedBox(height: 2),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final name = auth.user?.name ?? 'User';
                  return Text(name, style: AppTypography.displaySmall);
                },
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Open notifications',
          child: Consumer<NotificationService>(
            builder: (context, notifications, _) => Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showNotificationDialog(context),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.textOnPrimary,
                        size: 23,
                      ),
                      if (notifications.unreadCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryCard() {
    return Consumer<RoutePlannerProvider>(
      builder: (context, planner, _) {
        final vehicle = planner.selectedVehicle;
        if (vehicle == null) {
          return _HomeInfoCard(
            icon: Icons.directions_car_outlined,
            title: 'Add your EV details',
            message:
                'Save a car, bike or auto profile to unlock accurate range and charger compatibility.',
            onTap: () => context.push('/driver/vehicles'),
          );
        }
        return GlassCard(
          accentColor: AppColors.primary,
          padding: const EdgeInsets.all(22),
          borderRadius: 22,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BATTERY STATUS',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/driver/vehicles'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.onPrimary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.onPrimary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.edit_rounded,
                            color: AppColors.onPrimary,
                            size: 13,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Manage',
                            style: TextStyle(
                              color: AppColors.onPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Live battery percentage is available during an active session.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onPrimary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _batteryMetric(
                    Icons.bolt_rounded,
                    '${vehicle.batteryKwh.toStringAsFixed(1)} kWh',
                    'Capacity',
                    AppColors.primary,
                  ),
                  _batteryMetric(
                    Icons.route_rounded,
                    vehicle.estimatedRangeKm == null
                        ? '—'
                        : '${vehicle.estimatedRangeKm!.round()} km',
                    'Range',
                    AppColors.primary,
                  ),
                  _batteryMetric(
                    Icons.ev_station_rounded,
                    vehicle.primaryConnector,
                    'Connector',
                    AppColors.secondary,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _batteryMetric(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
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
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.onPrimary.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => context.go('/driver/map'),
      child: GlassCard(
        accentColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 14,
        blur: 12,
        opacity: 0.55,
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: AppColors.onPrimary.withValues(alpha: 0.7),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search destination or charger...',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onPrimary.withValues(alpha: 0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (
        Icons.route_rounded,
        'Route\nPlanner',
        AppColors.primary,
        '/driver/route-planner',
      ),
      (
        Icons.ev_station_rounded,
        'Find\nCharger',
        AppColors.success,
        '/driver/map',
      ),
      (
        Icons.bolt_rounded,
        'Active\nSession',
        AppColors.secondary,
        '/driver/session',
      ),
      (
        Icons.history_rounded,
        'Booking\nHistory',
        AppColors.warning,
        '/driver/history',
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: actions.map((a) {
        return GestureDetector(
          onTap: () => context.go(a.$4),
          child: Column(
            children: [
              GlassCard(
                accentColor: a.$3,
                padding: const EdgeInsets.all(0),
                borderRadius: 18,
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: Icon(a.$1, color: AppColors.onPrimary, size: 28),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                a.$2,
                textAlign: TextAlign.center,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      children: [
        Text('01', style: AppTypography.sectionNumber),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppColors.border)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.sectionLabel,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => context.go('/driver/map'),
          child: Text(
            action,
            style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyChargers() {
    return Consumer<ChargerDiscoveryProvider>(
      builder: (context, discovery, _) {
        if (discovery.chargersLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final chargers = discovery.filteredChargers;

        if (chargers.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.ev_station_rounded,
                  color: AppColors.textMuted,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  discovery.chargersError != null
                      ? 'Unable to load chargers'
                      : 'No chargers nearby',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                if (discovery.chargersError != null) ...[
                  const SizedBox(height: 8),
                  Text('Pull down to retry', style: AppTypography.bodySmall),
                ],
              ],
            ),
          );
        }

        return Column(
          children: chargers.take(5).map((charger) {
            final distance = discovery.distanceTo(charger);
            final distanceLabel = distance > 0
                ? '${distance.toStringAsFixed(1)} km away'
                : charger.address ?? '';

            final statusColor = charger.chargerStatus == ChargerStatus.available
                ? AppColors.success
                : charger.chargerStatus == ChargerStatus.busy
                ? AppColors.warning
                : AppColors.textMuted;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChargerCard(
                name: charger.name,
                power: '${charger.powerKw.round()} kW',
                price: '₹${charger.basePrice.round()}/kWh',
                status: charger.chargerStatus,
                address: distanceLabel,
                rating: charger.rating,
                amenities: charger.amenitiesList,
                onTap: () => context.go('/driver/charger/${charger.id}'),
                glass: true,
                accentColor: statusColor,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ─── CHARGERS TAB ───
  Widget _buildChargersTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All Chargers', style: AppTypography.displaySmall),
          const SizedBox(height: 16),
          Consumer<ChargerDiscoveryProvider>(
            builder: (context, discovery, _) {
              return TextField(
                controller: _searchController,
                onChanged: discovery.setSearchQuery,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search chargers...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<ChargerDiscoveryProvider>(
              builder: (context, discovery, _) {
                if (discovery.chargersLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final chargers = discovery.filteredChargers;

                if (chargers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          color: AppColors.textMuted,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No chargers found',
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => discovery.refreshChargers(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: chargers.length,
                    itemBuilder: (context, index) {
                      final charger = chargers[index];
                      final distance = discovery.distanceTo(charger);
                      final distanceLabel = distance > 0
                          ? '${distance.toStringAsFixed(1)} km away'
                          : charger.address ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ChargerCard(
                          name: charger.name,
                          power: '${charger.powerKw.round()} kW',
                          price: '₹${charger.basePrice.round()}/kWh',
                          status: charger.chargerStatus,
                          address: distanceLabel,
                          rating: charger.rating,
                          amenities: charger.amenitiesList,
                          onTap: () =>
                              context.go('/driver/charger/${charger.id}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── SPONSORS & INNOVATION HUB ───
  Widget _buildSponsorsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Copilot & Tariff Intelligence',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Powered by Google Gemini & Tavily Live Data',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showGeminiCopilotDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.psychology_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'AI Copilot',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _showDiscomTariffDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.insights_rounded,
                          color: AppColors.secondary,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Grid Tariffs',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showGeminiCopilotDialog(BuildContext context) async {
    final promptCtrl = TextEditingController(
      text: 'How should I choose the best charging stop for my trip?',
    );
    var advice = '';
    var loading = false;
    var adviceIsError = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return _buildSponsorDialog(
              context: context,
              icon: Icons.auto_awesome_rounded,
              accentColor: AppColors.primary,
              title: 'VoltEZ AI Copilot',
              subtitle: 'Charging guidance powered by Gemini',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key('gemini-prompt-field'),
                    controller: promptCtrl,
                    minLines: 3,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Ask Gemini Copilot',
                      labelStyle: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondary,
                      ),
                      hintText: 'e.g. Where can I find CCS2 50kW chargers?',
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                  ),
                  if (loading) ...[
                    const SizedBox(height: 16),
                    _buildDialogStatus(
                      accentColor: AppColors.primary,
                      title: 'Getting live advice…',
                      loading: true,
                    ),
                  ] else if (advice.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDialogStatus(
                      accentColor: adviceIsError
                          ? AppColors.error
                          : AppColors.primary,
                      title: adviceIsError
                          ? 'Copilot unavailable'
                          : 'Gemini response',
                      message: advice,
                      isError: adviceIsError,
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Text(
                      'Ask about compatible chargers, charging stops, or trip preparation.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              footer: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('CLOSE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      key: const Key('ask-ai-button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: loading
                          ? null
                          : () async {
                              final prompt = promptCtrl.text.trim();
                              if (prompt.length < 2) {
                                setState(() {
                                  advice = 'Enter a question before asking AI.';
                                  adviceIsError = true;
                                });
                                return;
                              }

                              setState(() {
                                loading = true;
                                advice = '';
                                adviceIsError = false;
                              });
                              try {
                                final planner = context
                                    .read<RoutePlannerProvider>();
                                final vehicle = planner.selectedVehicle;
                                final res = await ApiService().askSponsorCopilot({
                                  'prompt': prompt,
                                  // Keep the copilot grounded in route-planner
                                  // state instead of using demo vehicle data.
                                  'battery_level': planner.currentSOC.round(),
                                  if (vehicle != null) ...{
                                    'vehicle_model': vehicle.displayName,
                                    'connector_type': vehicle.primaryConnector,
                                  },
                                });
                                final data = res.data as Map<String, dynamic>;
                                if (!context.mounted) return;
                                setState(() {
                                  advice =
                                      data['advice']?.toString() ??
                                      'Advice is unavailable right now.';
                                  adviceIsError =
                                      data['provider_status']?.toString() !=
                                      'ok';
                                  loading = false;
                                });
                              } catch (_) {
                                if (!context.mounted) return;
                                setState(() {
                                  advice =
                                      'Live Gemini advice is unavailable right now. Please try again shortly.';
                                  adviceIsError = true;
                                  loading = false;
                                });
                              }
                            },
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.textOnPrimary,
                              ),
                            )
                          : const Text('ASK AI'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    promptCtrl.dispose();
  }

  Future<void> _showDiscomTariffDialog(BuildContext context) async {
    const stateName = 'Maharashtra';
    final tariffRequest = ApiService().getSponsorTariffs(stateName).then((res) {
      final data = res.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    });

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _buildSponsorDialog(
          context: dialogContext,
          icon: Icons.insights_rounded,
          accentColor: AppColors.secondary,
          title: 'DISCOM Grid Tariffs',
          subtitle: 'Live tariff sources for $stateName',
          content: FutureBuilder<Map<String, dynamic>>(
            future: tariffRequest,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildDialogStatus(
                  accentColor: AppColors.secondary,
                  title: 'Checking live tariff sources…',
                  loading: true,
                );
              }

              if (snapshot.hasError) {
                return _buildDialogStatus(
                  accentColor: AppColors.error,
                  title: 'Tariffs unavailable',
                  message:
                      'Live tariff sources could not be loaded. Please try again shortly.',
                  isError: true,
                );
              }

              final data = snapshot.data ?? <String, dynamic>{};
              final rawResults = data['results'];
              final tariffs = rawResults is List ? rawResults : <dynamic>[];
              final providerAvailable =
                  data['provider_status']?.toString() == 'ok';

              if (tariffs.isEmpty) {
                return _buildDialogStatus(
                  accentColor: AppColors.error,
                  title: 'No live tariffs found',
                  message: providerAvailable
                      ? 'No current tariff sources were returned for $stateName.'
                      : 'The live tariff provider is unavailable right now. Please try again shortly.',
                  isError: true,
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latest electricity-tariff references',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Verify the applicable DISCOM order before using a rate.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...tariffs.take(3).toList().asMap().entries.map((entry) {
                    final rawItem = entry.value;
                    final item = rawItem is Map<String, dynamic>
                        ? rawItem
                        : <String, dynamic>{};
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${entry.key + 1}',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item['title']?.toString() ?? 'Tariff reference',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          footer: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 124,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.onSecondary,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('DONE'),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSponsorDialog({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required Widget content,
    required Widget footer,
  }) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.headlineMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: content,
              ),
            ),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(16), child: footer),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogStatus({
    required Color accentColor,
    required String title,
    String? message,
    bool loading = false,
    bool isError = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isError ? 0.06 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: accentColor,
              ),
            )
          else
            Icon(
              isError ? Icons.info_outline_rounded : Icons.auto_awesome_rounded,
              color: accentColor,
              size: 21,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    color: isError ? AppColors.error : accentColor,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PROFILE TAB ───

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.secondary.withValues(alpha: 0.2),
                ],
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final name = auth.user?.name ?? 'User';
              return Text(name, style: AppTypography.displaySmall);
            },
          ),
          const SizedBox(height: 4),
          const Text('User', style: AppTypography.bodyMedium),
          const SizedBox(height: 32),

          // Profile options
          Consumer<RoutePlannerProvider>(
            builder: (context, planner, _) => _profileOption(
              Icons.directions_car_rounded,
              'My Vehicles',
              planner.selectedVehicle == null
                  ? 'Add or manage your EV profiles'
                  : '${planner.availableVehicles.length} saved · ${planner.selectedVehicle!.displayName} active',
              () => context.push('/driver/vehicles'),
            ),
          ),
          Consumer<AuthProvider>(
            builder: (context, auth, _) => _profileOption(
              Icons.person_outline_rounded,
              'Personal Details',
              auth.user?.email ?? 'View and edit your account information',
              () => _showPersonalDetailsDialog(context),
            ),
          ),
          _profileOption(
            Icons.receipt_long_rounded,
            'Booking History',
            'View all bookings and sessions',
            () => context.go('/driver/history'),
          ),
          _profileOption(
            Icons.verified_user_outlined,
            'KYC & Identity Verification',
            'Driving license / Aadhaar status',
            () => _showDriverKycDialog(context),
          ),
          _profileOption(
            Icons.payment_rounded,
            'Payment Methods',
            'UPI, cards or pay-at-charger cash',
            () => _showPaymentMethodsDialog(context),
          ),

          _profileOption(
            Icons.notifications_outlined,
            'Notifications',
            'Manage alerts',
            () => _showNotificationDialog(context),
          ),
          _profileOption(
            Icons.help_outline_rounded,
            'Help & Support',
            'FAQs, contact us',
            () => _showHelpDialog(context),
          ),
          _profileOption(
            Icons.info_outline_rounded,
            'About VoltEZ',
            'Version 1.0.0',
            () => _showAboutDialog(context),
          ),

          const SizedBox(height: 16),
          _profileOption(
            Icons.logout_rounded,
            'Logout',
            'Sign out of your account',
            () async {
              final auth = context.read<AuthProvider>();
              await auth.logout();
              if (!mounted) return;
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showPersonalDetailsDialog(BuildContext context) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PersonalDetailsDialog(user: user),
    );

    if (!context.mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Personal details updated successfully')),
    );
  }

  Widget _profileOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.headlineSmall),
                    Text(subtitle, style: AppTypography.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab() {
    return const Center(
      child: Text('Coming soon', style: TextStyle(color: AppColors.textMuted)),
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    showAboutDialog(
      context: context,
      applicationName: 'VoltEZ',
      applicationVersion: '1.0.0',
      applicationLegalese: 'Smart EV charging marketplace',
      children: const [
        SizedBox(height: 12),
        Text(
          'VoltEZ connects drivers with real, host-approved charging slots and keeps reservations, payments, sessions, and feedback auditable.',
        ),
      ],
    );
  }

  Future<void> _showDriverKycDialog(BuildContext context) async {
    final docNumber = TextEditingController();
    final rcNumber = TextEditingController();
    String docType = 'driving_license';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.verified_user_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(child: Text('User KYC Verification')),
            ],
          ),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verify your driving credentials to unlock instant slot holds, zero-deposit charging, and higher trust rating.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: docType,
                  decoration: const InputDecoration(labelText: 'Document Type'),

                  items: const [
                    DropdownMenuItem(
                      value: 'driving_license',
                      child: Text('Driving License (DL)'),
                    ),
                    DropdownMenuItem(
                      value: 'aadhaar',
                      child: Text('Aadhaar / National ID'),
                    ),
                    DropdownMenuItem(
                      value: 'voter_id',
                      child: Text('Voter ID'),
                    ),
                    DropdownMenuItem(
                      value: 'passport',
                      child: Text('Passport'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => docType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: docNumber,
                  decoration: const InputDecoration(
                    labelText: 'Document / ID Number (e.g. MH1220210001234)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rcNumber,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle RC Number (Optional)',
                  ),
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
                if (docNumber.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your document ID number.'),
                    ),
                  );
                  return;
                }
                try {
                  await context.read<ApiService>().submitUserKyc({
                    'document_type': docType,
                    'document_number': docNumber.text.trim(),
                    if (rcNumber.text.trim().isNotEmpty)
                      'vehicle_rc_number': rcNumber.text.trim(),
                  });
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'User identity submitted. Verification status: PENDING REVIEW',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Verification error: $e')),
                    );
                  }
                }
              },
              child: const Text('VERIFY & SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentMethodsDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    var selected = prefs.getString('voltez_default_payment_method') ?? 'upi';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Payment methods'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose the method preselected at checkout. Card and UPI are processed by the configured gateway; cash is settled with the host at arrival.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) setState(() => selected = value);
                },
                child: Column(
                  children: [
                    for (final option in const [
                      ('upi', 'UPI', Icons.account_balance_rounded),
                      ('card', 'Card', Icons.credit_card_rounded),
                      (
                        'cash',
                        'Pay at charger (cash)',
                        Icons.payments_outlined,
                      ),
                    ])
                      RadioListTile<String>(
                        value: option.$1,
                        title: Text(option.$2),
                        secondary: Icon(option.$3, color: AppColors.primary),
                      ),
                  ],
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () async {
                await prefs.setString(
                  'voltez_default_payment_method',
                  selected,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Default payment method saved.'),
                    ),
                  );
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotificationDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    var enabled = prefs.getBool('voltez_notifications_enabled') ?? true;
    final localAlerts = NotificationService.instance.alerts;
    NotificationService.instance.markAllRead();
    List<Map<String, dynamic>> notifications = const [];
    String? loadError;
    try {
      final response = await context.read<ApiService>().getNotifications();
      final data = response.data;
      if (data is List) {
        notifications = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (error) {
      loadError = 'Could not load server notifications. Pull to retry later.';
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Notifications'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.sizeOf(context).height * 0.46,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Notifications'),
                  value: enabled,
                  onChanged: (val) {
                    setDialogState(() => enabled = val);
                    prefs.setBool('voltez_notifications_enabled', val);
                  },
                ),
                const Divider(),
                Expanded(
                  child:
                      loadError != null &&
                          localAlerts.isEmpty &&
                          notifications.isEmpty
                      ? Center(
                          child: Text(
                            loadError,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : localAlerts.isEmpty && notifications.isEmpty
                      ? const Center(child: Text('No notifications yet.'))
                      : ListView.separated(
                          itemCount: localAlerts.length + notifications.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            if (i < localAlerts.length) {
                              final alert = localAlerts[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                title: Text(
                                  alert.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${alert.body}\n${_timeAgo(alert.time)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                isThreeLine: true,
                              );
                            }
                            final serverItem =
                                notifications[i - localAlerts.length];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.notifications_outlined,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              title: Text(
                                serverItem['title']?.toString() ?? '',
                              ),
                              subtitle: Text(
                                serverItem['message']?.toString() ?? '',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHelpDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'For assistance, email us at support@voltez.com or visit our FAQ page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}

class _PersonalDetailsDialog extends StatefulWidget {
  const _PersonalDetailsDialog({required this.user});

  final User user;

  @override
  State<_PersonalDetailsDialog> createState() => _PersonalDetailsDialogState();
}

class _PersonalDetailsDialogState extends State<_PersonalDetailsDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  var _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _emailController = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final success = await context.read<AuthProvider>().updateProfile(
      name: name,
      phone: phone.isEmpty ? null : phone,
    );
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSaving = false;
      _error = context.read<AuthProvider>().error ?? 'Unable to update profile';
    });
  }

  @override
  Widget build(BuildContext context) {
    final roleName = switch (widget.user.role.name) {
      'driver' => 'Driver',
      'owner' => 'Business Owner',
      _ => 'Admin',
    };

    return AlertDialog(
      title: const Text('Personal Details'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Account Type',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            child: Text(roleName),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('SAVE'),
        ),
      ],
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _HomeInfoCard extends StatelessWidget {
  const _HomeInfoCard({
    required this.icon,
    required this.title,
    required this.message,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.headlineSmall),
                  const SizedBox(height: 4),
                  Text(message, style: AppTypography.bodySmall),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ADD EV',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.add_rounded, color: AppColors.primary, size: 15),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
