import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/models/models.dart';

class DriverOnboardingScreen extends StatefulWidget {
  const DriverOnboardingScreen({super.key});

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  int _step = 0;
  final _pageController = PageController();

  // Vehicle info
  String? _selectedMake;
  String? _selectedModel;
  double _batteryCapacity = 40;
  double _currentBattery = 72;
  ConnectorType? _connectorType;
  double _reserveBattery = 15;

  final _makes = ['Tata', 'MG', 'Hyundai', 'Mahindra', 'Kia', 'BYD', 'Ather', 'Ola'];
  final _modelsByMake = {
    'Tata': ['Nexon EV', 'Tiago EV', 'Punch EV', 'Harrier EV'],
    'MG': ['ZS EV', 'Comet EV'],
    'Hyundai': ['Ioniq 5', 'Kona Electric'],
    'Mahindra': ['XUV400', 'XUV.e8'],
    'Kia': ['EV6', 'EV9'],
    'BYD': ['Atto 3', 'Seal', 'e6'],
    'Ather': ['450X', '450S'],
    'Ola': ['S1 Pro', 'S1 Air'],
  };

  List<String> get _selectedModels => _modelsByMake[_selectedMake] ?? [];

  void _next() {
    if (_step < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _step++);
    } else {
      // Complete onboarding
      context.go('/driver/home');
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
      context.pop();
    }
  }

  bool get _canProceed {
    switch (_step) {
      case 0: return _selectedMake != null && _selectedModel != null;
      case 1: return _connectorType != null;
      case 2: return true;
      default: return false;
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
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) => Container(
                        width: i == _step ? 32 : 8,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _step ? AppColors.primary : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )),
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
                text: _step == 2 ? 'COMPLETE SETUP' : 'CONTINUE',
                onPressed: _canProceed ? _next : null,
                isExpanded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STEP 1: Vehicle Selection ───
  Widget _buildVehicleStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STEP 1', style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
          const SizedBox(height: 8),
          Text('Select your vehicle', style: AppTypography.displaySmall),
          const SizedBox(height: 6),
          Text('Choose your EV make and model for personalised charging.', style: AppTypography.bodyMedium),
          const SizedBox(height: 28),

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
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    make,
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.textSecondary,
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
                      color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: selected ? AppColors.primary : AppColors.textMuted,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          model,
                          style: TextStyle(
                            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
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
          Text('STEP 2', style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
          const SizedBox(height: 8),
          Text('Connector type', style: AppTypography.displaySmall),
          const SizedBox(height: 6),
          Text('What connector does your vehicle use?', style: AppTypography.bodyMedium),
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
            };

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _connectorType = type),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.card,
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
                          color: selected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.power_rounded,
                          color: selected ? AppColors.primary : AppColors.textMuted,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: AppTypography.headlineSmall.copyWith(
                              color: selected ? AppColors.primary : AppColors.textPrimary,
                            )),
                            const SizedBox(height: 3),
                            Text(description, style: AppTypography.bodySmall),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24),
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
          Text('STEP 3', style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
          const SizedBox(height: 8),
          Text('Battery settings', style: AppTypography.displaySmall),
          const SizedBox(height: 6),
          Text('Set your battery details for accurate range estimates.', style: AppTypography.bodyMedium),
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
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                _summaryRow('Vehicle', '${_selectedMake ?? ''} ${_selectedModel ?? ''}'),
                _summaryRow('Connector', _connectorType?.name.toUpperCase().replaceAll('_', ' ') ?? ''),
                _summaryRow('Capacity', '${_batteryCapacity.round()} kWh'),
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
            Text(title, style: AppTypography.headlineMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${value.round()} $unit',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
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
          Text(label, style: AppTypography.bodyMedium),
          Text(value, style: AppTypography.headlineSmall.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}
