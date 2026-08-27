import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';

const _bg = Color(0xFF05090E);
const _panel = Color(0xFF0D1821);
const _cyan = Color(0xFF50F5FF);
const _lime = Color(0xFFC9FF58);
const _text = Color(0xFFF1F8FF);
const _muted = Color(0xFF7990A1);

class BusinessOnboardingScreen extends StatefulWidget {
  const BusinessOnboardingScreen({super.key});

  @override
  State<BusinessOnboardingScreen> createState() =>
      _BusinessOnboardingScreenState();
}

class _BusinessOnboardingScreenState
    extends State<BusinessOnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentStep = 0;

  final TextEditingController _businessNameController =
      TextEditingController();

  final TextEditingController _addressController =
      TextEditingController();

  String _category = 'EV Charging Station';

  TimeOfDay _openingTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 22, minute: 0);

  final List<String> _categories = [
    'EV Charging Station',
    'Hotel',
    'Restaurant',
    'Shopping Centre',
    'Office / Corporate',
    'Parking Facility',
    'Other',
  ];

  final List<Map<String, dynamic>> _chargers = [
    {
      'name': 'Charger 01',
      'power': '60 kW',
      'connector': 'CCS2',
      'price': '₹15 / kWh',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _businessNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });

      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });

      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _finishOnboarding() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const DashboardScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _selectTime({
    required bool opening,
  }) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: opening ? _openingTime : _closingTime,
    );

    if (selected == null) return;

    setState(() {
      if (opening) {
        _openingTime = selected;
      } else {
        _closingTime = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildProgress(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBusinessProfile(),
                  _buildLocationAndHours(),
                  _buildChargerSetup(),
                ],
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _cyan.withValues(alpha: 0.15),
              ),
            ),
            child: const Icon(
              Icons.ev_station_rounded,
              color: _cyan,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOLTEZ / BUSINESS',
                  style: TextStyle(
                    color: _cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Set up your charging network',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_currentStep + 1}/3',
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
      child: Row(
        children: List.generate(
          3,
          (index) {
            final active = index <= _currentStep;

            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(
                  right: index == 2 ? 0 : 6,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? _cyan
                      : _panel,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBusinessProfile() {
    return _scrollableStep(
      children: [
        _stepHeader(
          number: '01',
          title: 'BUSINESS PROFILE',
          subtitle: 'Tell us about your charging location.',
        ),
        const SizedBox(height: 28),

        _fieldLabel('BUSINESS NAME'),
        const SizedBox(height: 8),

        _textField(
          controller: _businessNameController,
          hint: 'e.g. ABC Motors',
          icon: Icons.business_rounded,
        ),

        const SizedBox(height: 22),

        _fieldLabel('BUSINESS CATEGORY'),
        const SizedBox(height: 8),

        _dropdown(
          value: _category,
          items: _categories,
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _category = value;
            });
          },
        ),

        const SizedBox(height: 24),

        _infoCard(
          icon: Icons.auto_awesome_rounded,
          title: 'WHY WE ASK',
          description:
              'Your business category helps Voltez understand '
              'charging demand patterns around your location.',
        ),
      ],
    );
  }

  Widget _buildLocationAndHours() {
    return _scrollableStep(
      children: [
        _stepHeader(
          number: '02',
          title: 'LOCATION & HOURS',
          subtitle: 'Set where and when your chargers operate.',
        ),
        const SizedBox(height: 28),

        _fieldLabel('BUSINESS ADDRESS'),
        const SizedBox(height: 8),

        _textField(
          controller: _addressController,
          hint: 'Enter your business address',
          icon: Icons.location_on_outlined,
          maxLines: 2,
        ),

        const SizedBox(height: 16),

        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _cyan.withValues(alpha: 0.12),
            ),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.location_on_rounded,
                  color: _cyan,
                  size: 40,
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _bg.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        color: _cyan,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'MAP PIN WILL BE ADDED HERE',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _fieldLabel('OPENING HOURS'),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _timeCard(
                label: 'OPENS',
                time: _openingTime,
                onTap: () => _selectTime(opening: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _timeCard(
                label: 'CLOSES',
                time: _closingTime,
                onTap: () => _selectTime(opening: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChargerSetup() {
    return _scrollableStep(
      children: [
        _stepHeader(
          number: '03',
          title: 'CHARGER SETUP',
          subtitle: 'Configure the ports available to drivers.',
        ),
        const SizedBox(height: 24),

        ..._chargers.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _chargerCard(
              index: entry.key,
              charger: entry.value,
            ),
          ),
        ),

        const SizedBox(height: 4),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _addCharger,
            icon: const Icon(
              Icons.add_rounded,
              size: 18,
            ),
            label: const Text('ADD ANOTHER CHARGER'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _cyan,
              side: BorderSide(
                color: _cyan.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        _infoCard(
          icon: Icons.verified_user_outlined,
          title: 'TRUSTED SETUP',
          description:
              'Charger information can be updated later from '
              'Charger Management.',
        ),
      ],
    );
  }

  Widget _scrollableStep({
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _stepHeader({
    required String number,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: _lime,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: _text,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _muted,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: _text,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: _muted,
          fontSize: 12,
        ),
        prefixIcon: Icon(
          icon,
          color: _cyan,
          size: 19,
        ),
        filled: true,
        fillColor: _panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: _cyan,
            width: 1,
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: _panel,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _cyan,
          ),
          style: const TextStyle(
            color: _text,
            fontSize: 12,
          ),
          items: items.map(
            (item) {
              return DropdownMenuItem(
                value: item,
                child: Text(item),
              );
            },
          ).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _timeCard({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: _cyan,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Text(
                  time.format(context),
                  style: const TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chargerCard({
    required int index,
    required Map<String, dynamic> charger,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _cyan.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.ev_station_rounded,
                  color: _cyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  charger['name'],
                  style: const TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'PORT ${index + 1}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _chargerInfo(
                  'POWER',
                  charger['power'],
                ),
              ),
              Expanded(
                child: _chargerInfo(
                  'CONNECTOR',
                  charger['connector'],
                ),
              ),
              Expanded(
                child: _chargerInfo(
                  'PRICE',
                  charger['price'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chargerInfo(
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 7,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: _text,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _cyan.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _cyan.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: _cyan,
            size: 19,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _cyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addCharger() {
    setState(() {
      final number = _chargers.length + 1;

      _chargers.add({
        'name': 'Charger ${number.toString().padLeft(2, '0')}',
        'power': '60 kW',
        'connector': 'CCS2',
        'price': '₹15 / kWh',
      });
    });
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _muted,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    'BACK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0)
            const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cyan,
                  foregroundColor: _bg,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(
                  _currentStep == 2
                      ? 'COMPLETE SETUP'
                      : 'CONTINUE',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}