import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/network/api_service.dart';
import '../../../core/providers/route_planner_provider.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/models/models.dart';

class DriverOnboardingScreen extends StatefulWidget {
  const DriverOnboardingScreen({super.key, this.vehicleToEdit});

  final Vehicle? vehicleToEdit;

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  int _step = 0;
  final _pageController = PageController();

  // Vehicle info
  String? _selectedMake;
  String? _selectedModel;
  String _vehicleClass = 'car';
  double _batteryCapacity = 40;
  double _estimatedRangeKm = 300;
  double _currentBattery = 72;
  ConnectorType? _connectorType;
  double _reserveBattery = 15;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final existing = widget.vehicleToEdit;
    if (existing == null) return;
    _selectedMake = existing.make;
    _selectedModel = existing.model;
    _batteryCapacity = existing.batteryKwh;
    _estimatedRangeKm = existing.estimatedRangeKm ?? _estimatedRangeKm;
    _connectorType = _connectorFromName(existing.primaryConnector);
  }

  // Covers the major Indian EV catalogue, including the two-wheelers most
  // commonly seen on Indian roads. "Other" remains available for imports and
  // newly launched models without pretending this list is exhaustive.
  final _makes = [
    'Tata',
    'MG',
    'Hyundai',
    'Mahindra',
    'Kia',
    'BYD',
    'Citroen',
    'Volvo',
    'BMW',
    'Mercedes-Benz',
    'Audi',
    'Porsche',
    'Ather',
    'Ola',
    'TVS',
    'Bajaj',
    'Revolt',
    'Ultraviolette',
    'Matter',
    'Hero Electric',
    'Ampere',
    'Okinawa',
    'Vida',
    'Simple Energy',
    'Oben',
    'River',
    'Tork',
    'Joy e-bike',
    'PURE EV',
    'Komaki',
    'EeVe',
    'Bounce',
    'BGauss',
    'Lectrix',
    'Raptee',
    'Hop Electric',
    'Odysse',
    'Other',
  ];
  final _modelsByMake = {
    'Tata': [
      'Tiago EV',
      'Tigor EV',
      'Nexon EV',
      'Punch EV',
      'Curvv EV',
      'Harrier EV',
    ],
    'MG': ['Comet EV', 'ZS EV', 'Windsor EV', 'Cyberster'],
    'Hyundai': ['Kona Electric', 'Ioniq 5', 'Creta Electric'],
    'Mahindra': ['eVerito', 'XUV400', 'BE 6', 'XEV 9e'],
    'Kia': ['EV6', 'EV9', 'Carens Clavis EV'],
    'BYD': ['Atto 3', 'Seal', 'e6', 'Sealion 7'],
    'Citroen': ['eC3', 'eC3 Aircross'],
    'Volvo': ['XC40 Recharge', 'C40 Recharge', 'EX30'],
    'BMW': ['i4', 'i5', 'iX', 'i7'],
    'Mercedes-Benz': ['EQA', 'EQB', 'EQE', 'EQS'],
    'Audi': ['Q4 e-tron', 'Q8 e-tron', 'e-tron GT'],
    'Porsche': ['Taycan', 'Macan Electric'],
    'Ather': ['450S', '450X', '450 Apex', 'Rizta'],
    'Ola': ['S1 Pro', 'S1 Air', 'S1X', 'S1X+', 'S1Z', 'Roadster'],
    'TVS': ['iQube', 'iQube ST', 'X'],
    'Bajaj': ['Chetak Premium', 'Chetak Urbane', 'Chetak 2901'],
    'Revolt': ['RV400', 'RV1', 'RV1+', 'RV BlazeX'],
    'Ultraviolette': ['F77', 'F77 Mach 2', 'F77 SuperStreet', 'Tesseract'],
    'Matter': ['Aera 5000', 'Aera 5000+'],
    'Hero Electric': ['Optima', 'NYX', 'Photon', 'Atria', 'Dash'],
    'Ampere': ['Magnus EX', 'Magnus Neo', 'Primus', 'Nexus', 'Zeal EX', 'Reo'],
    'Okinawa': [
      'Ridge+',
      'PraisePro',
      'iPraise+',
      'Okhi90',
      'R30',
      'Lite',
      'Dual 100',
      'Cruiser',
    ],
    'Vida': ['V1 Plus', 'V1 Pro', 'V2', 'VX2'],
    'Simple Energy': ['One', 'Dot One'],
    'Oben': ['Rorr', 'Rorr EZ'],
    'River': ['Indie'],
    'Tork': ['Kratos R', 'Kratos R Urban'],
    'Joy e-bike': [
      'Beast',
      'Hurricane',
      'Mihos',
      'Wolf',
      'Wolf+',
      'Gen Next Nanu',
    ],
    'PURE EV': ['ePluto 7G', 'eTrance Neo', 'eTron+'],
    'Komaki': ['Ranger', 'Venice', 'XGT VP', 'Flora'],
    'EeVe': ['Ahava', 'Xeniaa', 'Wind', 'Atreo'],
    'Bounce': ['Infinity E1'],
    'BGauss': ['D15', 'C12', 'RUV350'],
    'Lectrix': ['LXS G3.0', 'LXS 2.0'],
    'Raptee': ['T30'],
    'Hop Electric': ['Leo', 'OXO'],
    'Odysse': ['E2Go', 'Hawk'],
    'Other': ['Custom model'],
  };

  List<String> get _selectedModels => _modelsByMake[_selectedMake] ?? [];

  Future<void> _next() async {
    if (_step < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _step++);
    } else {
      await _saveVehicle();
    }
  }

  Future<void> _saveVehicle() async {
    final make = _selectedMake;
    final model = _selectedModel;
    final connector = _connectorType;
    if (make == null || model == null || connector == null || _saving) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final payload = <String, dynamic>{
        'make': make,
        'model': model,
        'vehicle_class': _vehicleClass,
        'battery_kwh': _batteryCapacity,
        'connector_type_ids': [_connectorId(connector)],
        'max_ac_kw': _vehicleClass == 'two_wheeler' ? 3.3 : 7.2,
        if (_vehicleClass != 'two_wheeler')
          'max_dc_kw': _vehicleClass == 'three_wheeler' ? 15.0 : 60.0,
        'estimated_range_km': _estimatedRangeKm,
      };
      final response = widget.vehicleToEdit == null
          ? await context.read<ApiService>().createVehicle(payload)
          : await context.read<ApiService>().updateVehicle(
              widget.vehicleToEdit!.id,
              payload,
            );
      if (!mounted) return;
      final savedId = (response.data as Map<String, dynamic>)['id']?.toString();
      await context.read<RoutePlannerProvider>().loadVehicles(
        selectedVehicleId: savedId ?? widget.vehicleToEdit?.id,
      );
      if (!mounted) return;
      // Return to wherever the wizard was opened from (home / vehicle
      // management). Fall back to home when this route is a top-level entry.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/driver/home');
      }
    } on DioException catch (error) {
      if (!mounted) return;
      final detail = error.response?.data;
      setState(
        () => _saveError = detail is Map && detail['detail'] is String
            ? detail['detail'] as String
            : 'Vehicle could not be saved. Check your connection and try again.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError =
              'Vehicle could not be saved. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _connectorId(ConnectorType connector) => switch (connector) {
    ConnectorType.ccs2 => 1,
    ConnectorType.type2 => 2,
    ConnectorType.chademo => 3,
    ConnectorType.gbT => 7,
    ConnectorType.type1 => 6,
    ConnectorType.bharatAc => 4,
    ConnectorType.bharatDc => 5,
  };

  ConnectorType _connectorFromName(String value) {
    switch (value.toLowerCase().replaceAll('-', '').replaceAll(' ', '')) {
      case 'ccs2':
        return ConnectorType.ccs2;
      case 'type2':
        return ConnectorType.type2;
      case 'chademo':
        return ConnectorType.chademo;
      case 'gb/t':
      case 'gbt':
        return ConnectorType.gbT;
      case 'type1':
        return ConnectorType.type1;
      case 'bharatac':
      case 'bharatac001':
        return ConnectorType.bharatAc;
      case 'bharatdc':
      case 'bharatdc001':
        return ConnectorType.bharatDc;
      default:
        return ConnectorType.type2;
    }
  }

  void _back() {
    if (_step > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _step--);
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/driver/home');
      }
    }
  }

  bool get _canProceed {
    switch (_step) {
      case 0:
        return _selectedMake != null && _selectedModel != null;
      case 1:
        return _connectorType != null;
      case 2:
        return true;
      default:
        return false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top Bar ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Container(
                          width: i == _step ? 32 : 8,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i <= _step
                                ? AppColors.primary
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ─── Pages ───
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildVehicleStep(),
                  _buildConnectorStep(),
                  _buildBatteryStep(),
                ],
              ),
            ),

            // ─── Bottom Button ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: PrimaryButton(
                text: _saving
                    ? 'SAVING…'
                    : _step == 2
                    ? 'COMPLETE SETUP'
                    : 'CONTINUE',
                onPressed: _canProceed && !_saving ? _next : null,
                isExpanded: true,
              ),
            ),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: Text(
                  _saveError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── STEP 1: Vehicle Selection ───
  Widget _buildVehicleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP 1',
            style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text('Select your vehicle', style: AppTypography.displaySmall),
          const SizedBox(height: 6),
          Text(
            'Choose your EV make and model for personalised charging.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 28),

          Text('Vehicle type', style: AppTypography.labelLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                  ('car', 'Car (hatchback / sedan / SUV)'),
                  ('two_wheeler', 'Bike / scooter'),
                  ('three_wheeler', 'Auto / 3-wheeler'),
                ].map((item) {
                  final selected = _vehicleClass == item.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _vehicleClass = item.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.14)
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        item.$2,
                        style: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 20),

          // Make selector
          Text('Make', style: AppTypography.labelLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _makes.map((make) {
              final selected = _selectedMake == make;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedMake = make;
                  _selectedModel = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    make,
                    style: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (_selectedMake != null) ...[
            const SizedBox(height: 28),
            Text('Model', style: AppTypography.labelLarge),
            const SizedBox(height: 10),
            ...(_selectedModels).map((model) {
              final selected = _selectedModel == model;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedModel = model),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            model,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ─── STEP 2: Connector & Battery ───
  Widget _buildConnectorStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP 2',
            style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text('Connector type', style: AppTypography.displaySmall),
          const SizedBox(height: 6),
          Text(
            'What connector does your vehicle use?',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 28),

          ...ConnectorType.values.map((type) {
            final selected = _connectorType == type;
            final name = type.name.toUpperCase().replaceAll('_', ' ');
            final description = switch (type) {
              ConnectorType.ccs2 => 'Most common DC fast charging',
              ConnectorType.type2 => 'Standard AC charging',
              ConnectorType.chademo => 'DC fast charging (Japanese)',
              ConnectorType.gbT => 'Chinese standard',
              ConnectorType.type1 => 'AC charging (North America)',
              ConnectorType.bharatAc =>
                'Bharat AC-001 for two-wheelers and light EVs',
              ConnectorType.bharatDc => 'Bharat DC-001 fast charging',
            };

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _connectorType = type),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.power_rounded,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textMuted,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTypography.headlineSmall.copyWith(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(description, style: AppTypography.bodySmall),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── STEP 3: Battery Capacity ───
  Widget _buildBatteryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP 3',
            style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text('Battery settings', style: AppTypography.displaySmall),
          const SizedBox(height: 6),
          Text(
            'Set your battery details for accurate range estimates.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Battery Capacity
          _sliderSection(
            title: 'Battery Capacity',
            value: _batteryCapacity,
            min: 10,
            max: 100,
            unit: 'kWh',
            color: AppColors.primary,
            onChanged: (v) => setState(() => _batteryCapacity = v),
          ),
          const SizedBox(height: 32),

          _sliderSection(
            title: 'Estimated real-world range',
            subtitle:
                'Use the range you normally get, not the brochure maximum.',
            value: _estimatedRangeKm,
            min: 40,
            max: 800,
            unit: 'km',
            color: AppColors.secondary,
            onChanged: (v) => setState(() => _estimatedRangeKm = v),
          ),
          const SizedBox(height: 32),

          // Current Battery %
          _sliderSection(
            title: 'Current Battery',
            value: _currentBattery,
            min: 0,
            max: 100,
            unit: '%',
            color: _currentBattery > 50
                ? AppColors.success
                : _currentBattery > 20
                ? AppColors.warning
                : AppColors.error,
            onChanged: (v) => setState(() => _currentBattery = v),
          ),
          const SizedBox(height: 32),

          // Reserve Battery %
          _sliderSection(
            title: 'Reserve Battery',
            subtitle: 'Stop searching when battery hits this level',
            value: _reserveBattery,
            min: 5,
            max: 30,
            unit: '%',
            color: AppColors.warning,
            onChanged: (v) => setState(() => _reserveBattery = v),
          ),
          const SizedBox(height: 24),

          // Summary card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                _summaryRow(
                  'Vehicle',
                  '${_selectedMake ?? ''} ${_selectedModel ?? ''}',
                ),
                _summaryRow(
                  'Connector',
                  _connectorType?.name.toUpperCase().replaceAll('_', ' ') ?? '',
                ),
                _summaryRow('Capacity', '${_batteryCapacity.round()} kWh'),
                _summaryRow('Vehicle type', _vehicleClass.replaceAll('_', ' ')),
                _summaryRow('Range', '${_estimatedRangeKm.round()} km'),
                _summaryRow('Current', '${_currentBattery.round()}%'),
                _summaryRow('Reserve', '${_reserveBattery.round()}%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderSection({
    required String title,
    String? subtitle,
    required double value,
    required double min,
    required double max,
    required String unit,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTypography.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${value.round()} $unit',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),

        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: AppTypography.bodySmall),
        ],
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),

    );
  }
}
