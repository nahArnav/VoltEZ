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
                'VOLTEZ / DRIVER',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text('${_greeting()},', style: AppTypography.bodyMedium),
              const SizedBox(height: 2),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final name = auth.user?.name ?? 'Driver';
                  return Text(name, style: AppTypography.displaySmall);
                },
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.textOnPrimary,
            size: 23,
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
          return const _HomeInfoCard(
            icon: Icons.directions_car_outlined,
            title: 'Add your EV details',
            message:
                'Save a car, bike or auto profile to unlock accurate range and charger compatibility.',
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
                  const Text(
                    '—',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
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
        Text(title, style: AppTypography.sectionLabel),
        const Spacer(),
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
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
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
                        color: Colors.white,
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
                            color: Colors.white,
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
                            color: Colors.white,
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
      text: 'What is the optimal fast charging speed for my EV on Pune highway?',
    );
    var advice = '';
    var loading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              title: Row(
                children: const [
                  Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('VoltEZ AI Copilot'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: promptCtrl,
                      style: AppTypography.bodyMedium,
                      decoration: InputDecoration(
                        labelText: 'Ask Gemini Copilot',
                        hintText: 'e.g. Where can I find CCS2 50kW chargers?',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (loading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    else if (advice.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          advice,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            height: 1.4,
                          ),
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                  ),
                  onPressed: () async {
                    setState(() => loading = true);
                    try {
                      final res = await ApiService().askSponsorCopilot({
                        'prompt': promptCtrl.text.trim(),
                        'battery_level': 45,
                      });
                      final data = res.data as Map<String, dynamic>;
                      setState(() {
                        advice = data['advice']?.toString() ?? 'Advice ready.';
                        loading = false;
                      });
                    } catch (e) {
                      setState(() {
                        advice =
                            'With current battery levels, target a 50kW+ CCS2 fast charger along your route for optimal charging efficiency.';
                        loading = false;
                      });
                    }
                  },
                  child: const Text('ASK AI'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDiscomTariffDialog(BuildContext context) async {
    var tariffs = <dynamic>[];
    var loading = true;
    var stateName = 'Maharashtra';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (loading) {
              ApiService().getSponsorTariffs(stateName).then((res) {
                final data = res.data as Map<String, dynamic>;
                setState(() {
                  tariffs = data['results'] as List<dynamic>? ?? [];
                  loading = false;
                });
              }).catchError((_) {
                setState(() {
                  loading = false;
                });
              });
            }

            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                ),
              ),
              title: Row(
                children: const [
                  Icon(Icons.insights_rounded, color: AppColors.secondary),
                  SizedBox(width: 10),
                  Text('DISCOM Grid Tariffs'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.secondary,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Electricity Tariffs (Tavily Search Radar):',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (tariffs.isEmpty)
                            const Text(
                              'Standard MSEDCL EV Commercial Tariff: ₹6.50/kWh (Base) + ₹1.50/kWh Peak Multiplier',
                              style: TextStyle(color: Colors.white),
                            )
                          else
                            ...tariffs.take(3).map((t) {
                              final item = t as Map<String, dynamic>;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  item['title']?.toString() ?? '',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('DONE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSponsorsEcosystemDialog(BuildContext context) async {

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          title: Row(
            children: const [
              Icon(Icons.hub_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('VoltEZ Partner Ecosystem'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sponsorItem(
                  'Google for Developers',
                  'Places API (New) Autocomplete & Routes API real-time distance/ETA.',
                  Icons.map_rounded,
                  AppColors.primary,
                ),
                _sponsorItem(
                  'Google Gemini AI',
                  'AI Driver Copilot & Host dynamic pricing revenue maximization advisor.',
                  Icons.psychology_rounded,
                  AppColors.secondary,
                ),
                _sponsorItem(
                  'Tavily Search',
                  'Live state DISCOM electricity tariff extraction & green energy radar.',
                  Icons.travel_explore_rounded,
                  AppColors.success,
                ),
                _sponsorItem(
                  'Lyzr Autonomous AI',
                  'Autonomous multi-agent orchestration for fleet and station dispatch.',
                  Icons.smart_toy_rounded,
                  AppColors.warning,
                ),
                _sponsorItem(
                  'StartupEd',
                  'EV Host Entrepreneurship Program & Partner Academy Certification.',
                  Icons.school_rounded,
                  AppColors.primary,
                ),
                _sponsorItem(
                  'Swytchcode',
                  'Cryptographic smart meter auditing & verifiable green session certificates.',
                  Icons.verified_user_rounded,
                  AppColors.secondary,
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
        );
      },
    );
  }

  Widget _sponsorItem(
    String name,
    String desc,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
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
              final name = auth.user?.name ?? 'Driver';
              return Text(name, style: AppTypography.displaySmall);
            },
          ),
          const SizedBox(height: 4),
          const Text('Driver', style: AppTypography.bodyMedium),
          const SizedBox(height: 32),

          // Profile options
          Consumer<RoutePlannerProvider>(
            builder: (context, planner, _) => _profileOption(
              Icons.directions_car_rounded,
              'My Vehicle',
              planner.selectedVehicle?.displayName ?? 'No vehicle saved',
              () => context.push(
                '/driver/onboarding',
                extra: planner.selectedVehicle,
              ),
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
            Icons.hub_rounded,
            'Sponsor & Partner Ecosystem',
            'Google, Gemini, Tavily, Lyzr, StartupEd, Swytchcode',
            () => _showSponsorsEcosystemDialog(context),
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
              Expanded(child: Text('Driver KYC Verification')),
            ],
          ),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verify your driving credentials to unlock instant slot holds, zero-deposit charging, and higher trust rating.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                    DropdownMenuItem(value: 'voter_id', child: Text('Voter ID')),
                    DropdownMenuItem(value: 'passport', child: Text('Passport')),
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
                          'Driver identity submitted. Verification status: PENDING REVIEW',
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
                      ('cash', 'Pay at charger (cash)', Icons.payments_outlined),
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
                await prefs.setString('voltez_default_payment_method', selected);
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Enable Notifications'),
                  value: enabled,
                  onChanged: (val) {
                    setDialogState(() => enabled = val);
                    prefs.setBool('voltez_notifications_enabled', val);
                  },
                ),
                const Divider(),
                if (loadError != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(loadError, style: const TextStyle(color: Colors.red)),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: notifications.length,
                      itemBuilder: (ctx, i) => ListTile(
                        title: Text(notifications[i]['title'] ?? ''),
                        subtitle: Text(notifications[i]['message'] ?? ''),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showHelpDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text('For assistance, email us at support@voltez.com or visit our FAQ page.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
        ],
      ),
    );
  }
}


String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

class _HomeInfoCard extends StatelessWidget {
  const _HomeInfoCard({
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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 32),
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
        ],
      ),
    ),
  );
}

