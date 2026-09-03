import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/providers/route_planner_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/widgets.dart';

/// Driver "My Vehicles" manager.
///
/// Lists every saved EV (car / bike / auto), lets the driver pick which one is
/// used for route planning and charger compatibility, and links to the shared
/// add/edit vehicle wizard ([DriverOnboardingScreen]). Delete is destructive,
/// so it always asks for confirmation first.
class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() =>
      _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await context.read<RoutePlannerProvider>().loadVehicles();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = context.read<RoutePlannerProvider>().vehiclesError;
    });
  }

  Future<void> _openAddVehicle() async {
    await context.push('/driver/onboarding');
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openEditVehicle(Vehicle vehicle) async {
    await context.push('/driver/onboarding', extra: vehicle);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _confirmDelete(Vehicle vehicle) async {
    final api = context.read<ApiService>();
    final planner = context.read<RoutePlannerProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: Text(
          '${vehicle.displayName} will be removed from your profile. '
          'You can add it again any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('KEEP'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await api.deleteVehicle(vehicle.id);
      await planner.loadVehicles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${vehicle.displayName} removed.'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not remove the vehicle. Please retry.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: VoltAppBar(title: 'My Vehicles', subtitle: 'Manage your EV profiles'),
      body: SafeArea(
        child: Consumer<RoutePlannerProvider>(
          builder: (context, planner, _) {
            final vehicles = planner.availableVehicles;
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(
                    'Your saved EVs are used for route planning, range estimates and charger compatibility.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (vehicles.isEmpty)
                    _buildEmptyState()
                  else ...[
                    ...vehicles.map(
                      (vehicle) => _buildVehicleCard(planner, vehicle),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  PrimaryButton(
                    text: 'ADD A NEW EV',
                    onPressed: _openAddVehicle,
                    isExpanded: true,
                    icon: Icons.add_rounded,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_car_outlined,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text('No vehicles yet', style: AppTypography.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Add your car, bike or auto to unlock accurate range planning and charger compatibility.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(RoutePlannerProvider planner, Vehicle vehicle) {
    final isActive = planner.selectedVehicle?.id == vehicle.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.border,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.electric_car_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.displayName,
                      style: AppTypography.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${vehicle.batteryKwh.toStringAsFixed(1)} kWh · '
                      '${connectorTypeLabel(vehicle.primaryConnector)}'
                      '${vehicle.estimatedRangeKm != null ? ' · ${vehicle.estimatedRangeKm!.round()} km range' : ''}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
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
                child: OutlinedButton.icon(
                  onPressed: isActive
                      ? null
                      : () {
                          planner.selectVehicle(vehicle);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${vehicle.displayName} set as your planning vehicle.',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                  icon: const Icon(Icons.star_outline_rounded, size: 16),
                  label: const Text('USE FOR PLANNING'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openEditVehicle(vehicle),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('EDIT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove ${vehicle.displayName}',
                onPressed: () => _confirmDelete(vehicle),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
