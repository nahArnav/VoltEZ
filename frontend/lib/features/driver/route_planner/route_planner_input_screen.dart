import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/route_planner_provider.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/widgets.dart';

/// Route Planner — polished input screen.
///
/// Driver enters origin, destination, vehicle, battery SOC, reserve %,
/// and preference. Tapping "Find Best Charging Stop" triggers the
/// AI analysis → navigates to recommendations screen.
class RoutePlannerInputScreen extends StatefulWidget {
  const RoutePlannerInputScreen({super.key});

  @override
  State<RoutePlannerInputScreen> createState() =>
      _RoutePlannerInputScreenState();
}

class _RoutePlannerInputScreenState extends State<RoutePlannerInputScreen>
    with SingleTickerProviderStateMixin {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final planner = context.read<RoutePlannerProvider>();
      planner.loadVehicles();
      // Restore values left over from a previous planning session (e.g. when
      // the driver comes back from the results screen to tweak the trip).
      if (_originController.text.isEmpty && planner.originName.isNotEmpty) {
        _originController.text = planner.originName;
      }
      if (_destinationController.text.isEmpty &&
          planner.destinationName.isNotEmpty) {
        _destinationController.text = planner.destinationName;
      }
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<RoutePlannerProvider>(
        builder: (context, planner, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── Custom App Bar ───
              SliverToBoxAdapter(child: _buildHeader(planner)),

              // ─── Route Section ───
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildRouteSection(planner),
                    const SizedBox(height: 28),

                    // ─── Vehicle Section ───
                    _buildSectionLabel('VEHICLE', Icons.directions_car_rounded),
                    const SizedBox(height: 12),
                    _buildVehicleSelector(planner),
                    const SizedBox(height: 28),

                    // ─── Battery SOC ───
                    _buildSectionLabel(
                      'BATTERY STATE',
                      Icons.battery_charging_full_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildSOCSlider(planner),
                    const SizedBox(height: 20),
                    _buildReserveSlider(planner),
                    const SizedBox(height: 28),

                    // ─── Preference ───
                    _buildSectionLabel('PRIORITY', Icons.tune_rounded),
                    const SizedBox(height: 12),
                    _buildPreferenceGrid(planner),
                    const SizedBox(height: 32),

                    // ─── CTA ───
                    _buildCTA(planner),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader(RoutePlannerProvider planner) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/driver/home');
                  }
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Route Planner',
                      style: AppTypography.headlineLarge.copyWith(fontSize: 18),
                    ),
                    Text(
                      'Find the best charging stop on your trip',
                      style: AppTypography.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section Label (numbered) ───
  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Text(title, style: AppTypography.sectionLabel),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppColors.border)),
      ],
    );
  }

  // ─── Route Section (Origin + Destination + Visual) ───
  Widget _buildRouteSection(RoutePlannerProvider planner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: dots + connector line
          Padding(
            padding: const EdgeInsets.only(top: 22, right: 16),
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                ),
                Container(
                  width: 2,
                  height: 36,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.success.withValues(alpha: 0.5),
                        AppColors.primary.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Right: fields
          Expanded(
            child: Column(
              children: [
                // Origin field
                _buildRouteField(
                  controller: _originController,
                  label: 'From',
                  hint: planner.usingCurrentLocation
                      ? 'Current Location'
                      : 'Enter origin',
                  icon: Icons.my_location_rounded,
                  iconColor: AppColors.success,
                  planner: planner,
                  isFilled: planner.usingCurrentLocation,
                  trailing: planner.usingCurrentLocation
                      ? null
                      : _buildLocationButton(planner),
                  suggestions: planner.originSuggestions,
                  onSuggestionSelected: planner.selectOriginSuggestion,
                ),

                const SizedBox(height: 20),

                // Destination field
                _buildRouteField(
                  controller: _destinationController,
                  label: 'To',
                  hint: 'Enter destination',
                  icon: Icons.location_on_outlined,
                  iconColor: AppColors.primary,
                  planner: planner,
                  suggestions: planner.destinationSuggestions,
                  onSuggestionSelected: planner.selectDestinationSuggestion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required RoutePlannerProvider planner,
    bool isFilled = false,
    Widget? trailing,
    List<LocationSuggestion> suggestions = const [],
    ValueChanged<LocationSuggestion>? onSuggestionSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            isDense: true,
            prefixIcon: Icon(icon, color: iconColor, size: 20),
            suffixIcon: trailing,
          ),
          onChanged: (v) {
            if (label == 'From') {
              planner.setOrigin(v);
              planner.searchOrigin(v);
            } else {
              planner.setDestination(v);
              planner.searchDestination(v);
            }
          },
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.place_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      suggestion.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: onSuggestionSelected == null
                        ? null
                        : () {
                            onSuggestionSelected(suggestion);
                            controller.text = suggestion.label;
                            controller.selection = TextSelection.collapsed(
                              offset: controller.text.length,
                            );
                          },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationButton(RoutePlannerProvider planner) {
    return GestureDetector(
      onTap: () async {
        await planner.useCurrentLocation();
        if (planner.usingCurrentLocation) {
          _originController.text = 'Current Location';
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_fixed_rounded, color: AppColors.success, size: 14),
            const SizedBox(width: 4),
            Text(
              'GPS',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Vehicle Selector ───
  Widget _buildVehicleSelector(RoutePlannerProvider planner) {
    if (planner.availableVehicles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.directions_car_outlined,
              color: AppColors.primary,
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              'Add your EV to plan routes',
              style: AppTypography.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Route planning needs your vehicle\'s battery and connector type.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              text: 'ADD YOUR EV',
              onPressed: () => context.push('/driver/vehicles'),
              isExpanded: true,
              icon: Icons.add_rounded,
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: planner.availableVehicles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final vehicle = planner.availableVehicles[index];
          final selected = planner.selectedVehicle?.id == vehicle.id;

          return GestureDetector(
            onTap: () => planner.selectVehicle(vehicle),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 170,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Car icon + year
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.directions_car_rounded,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${vehicle.year}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Name
                  Text(
                    '${vehicle.make} ${vehicle.model}',
                    style: AppTypography.headlineSmall.copyWith(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Specs
                  Row(
                    children: [
                      _vehicleSpec(
                        Icons.battery_full_rounded,
                        '${vehicle.batteryCapacityKwh.round()} kWh',
                        selected,
                      ),
                      const SizedBox(width: 8),
                      _vehicleSpec(
                        Icons.power_rounded,
                        connectorTypeLabel(vehicle.primaryConnector),
                        selected,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _vehicleSpec(IconData icon, String text, bool selected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: selected ? AppColors.primary : AppColors.textMuted,
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ─── Battery SOC Slider ───
  Widget _buildSOCSlider(RoutePlannerProvider planner) {
    final soc = planner.currentSOC;
    final color = soc > 50
        ? AppColors.success
        : soc > 20
        ? AppColors.warning
        : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Battery visual
              _buildBatteryIcon(soc, color),
              const SizedBox(width: 16),

              // Label + percentage
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Battery', style: AppTypography.headlineSmall),
                    Text(
                      'How charged is your vehicle right now?',
                      style: AppTypography.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Big percentage
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${soc.round()}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: AppColors.surface,
              thumbColor: color,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayColor: color.withValues(alpha: 0.15),
              trackHeight: 6,
            ),
            child: Slider(
              value: soc,
              min: 5,
              max: 100,
              onChanged: (v) => planner.setCurrentSOC(v),
            ),
          ),

          // Range labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5%', style: AppTypography.labelSmall),
                Text('50%', style: AppTypography.labelSmall),
                Text('100%', style: AppTypography.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryIcon(double soc, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Battery outline
          Icon(Icons.battery_std_rounded, color: color, size: 32),
          // Fill level
          Positioned(
            bottom: 10,
            child: Container(
              width: 20 * (soc / 100).clamp(0.1, 1.0),
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reserve SOC Slider ───
  Widget _buildReserveSlider(RoutePlannerProvider planner) {
    final reserve = planner.reserveSOC;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.shield_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reserve Battery', style: AppTypography.headlineSmall),
                    Text(
                      'Minimum charge to keep as safety buffer',
                      style: AppTypography.bodySmall.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${reserve.round()}%',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.warning,
              inactiveTrackColor: AppColors.surface,
              thumbColor: AppColors.warning,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayColor: AppColors.warning.withValues(alpha: 0.15),
              trackHeight: 5,
            ),
            child: Slider(
              value: reserve,
              min: 5,
              max: 30,
              onChanged: (v) => planner.setReserveSOC(v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5%', style: AppTypography.labelSmall),
                Text('15%', style: AppTypography.labelSmall),
                Text('30%', style: AppTypography.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Preference Grid ───
  Widget _buildPreferenceGrid(RoutePlannerProvider planner) {
    final prefs = [
      (
        RecommendationPreference.fastest,
        Icons.speed_rounded,
        'Fastest',
        'Lowest trip ETA',
        AppColors.secondary,
      ),
      (
        RecommendationPreference.cheapest,
        Icons.savings_rounded,
        'Cheapest',
        'Lowest trip cost',
        AppColors.success,
      ),
      (
        RecommendationPreference.balanced,
        Icons.balance_rounded,
        'Balanced',
        'Time + cost + risk',
        AppColors.primary,
      ),
      (
        RecommendationPreference.reliable,
        Icons.verified_rounded,
        'Reliable',
        'Best predicted uptime',
        AppColors.warning,
      ),
    ];

    return GridView.builder(
      itemCount: prefs.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 112,
      ),
      itemBuilder: (context, index) {
        final p = prefs[index];
        final selected = planner.preference == p.$1;
        return GestureDetector(
          onTap: () => planner.setPreference(p.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? p.$5.withValues(alpha: 0.12) : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? p.$5 : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  p.$2,
                  color: selected ? p.$5 : AppColors.textMuted,
                  size: 22,
                ),
                const SizedBox(height: 6),
                Text(
                  p.$3,
                  style: AppTypography.headlineSmall.copyWith(
                    color: selected ? p.$5 : AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  p.$4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── CTA ───
  Widget _buildCTA(RoutePlannerProvider planner) {
    final valid = planner.canAttemptSearch;

    return Column(
      children: [
        if (planner.analysisError != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Text(
              planner.analysisError!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        // Compatibility note
        if (planner.selectedVehicle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Finding stops compatible with your '
                      '${planner.selectedVehicle!.make} ${planner.selectedVehicle!.model} '
                      '(${connectorTypeLabel(planner.selectedVehicle!.primaryConnector)}, '
                      '${planner.selectedVehicle!.batteryCapacityKwh.round()} kWh). '
                      'Calculating reachable stations based on your SOC.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Main CTA
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: valid ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: PrimaryButton(
            text: 'FIND BEST CHARGING STOP',
            onPressed: valid
                ? () async {
                    await planner.resolveTypedLocations();
                    if (!planner.isRouteValid) return;
                    await planner.findRecommendations();
                    if (!mounted) return;
                    if (planner.hasSearched && context.mounted) {
                      context.go('/driver/recommendations');
                    }
                  }
                : null,
            isExpanded: true,
            isLoading: planner.isAnalyzing,
            icon: Icons.auto_awesome_rounded,
            height: 56,
          ),
        ),

        if (!valid)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _getMissingHint(planner),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  String _getMissingHint(RoutePlannerProvider planner) {
    if (planner.originName.isEmpty && planner.destinationName.isEmpty) {
      return 'Enter origin and destination to continue';
    }
    if (planner.originName.isEmpty) return 'Enter your origin';
    if (planner.destinationName.isEmpty) return 'Enter your destination';
    if (planner.originLat == null || planner.destinationLat == null) {
      return 'Use GPS or enter places your phone can locate';
    }
    if (planner.selectedVehicle == null) {
      return 'Add your EV under VEHICLE above to continue';
    }
    return '';
  }
}
