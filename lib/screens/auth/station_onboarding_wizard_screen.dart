import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';

const Color _bg = Color(0xFF05090E);
const Color _panel = Color(0xFF0B141C);
const Color _cyan = Color(0xFF50F5FF);
const Color _lime = Color(0xFFC9FF58);
const Color _text = Color(0xFFF1F8FF);
const Color _muted = Color(0xFF7990A1);

class StationOnboardingWizardScreen extends StatefulWidget {
  final String hostName;

  const StationOnboardingWizardScreen({super.key, this.hostName = 'Host'});

  @override
  State<StationOnboardingWizardScreen> createState() => _StationOnboardingWizardScreenState();
}

class _StationOnboardingWizardScreenState extends State<StationOnboardingWizardScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Wizard Data State
  final _stationNameController = TextEditingController(text: "VoltHub Prime");
  final _locationController = TextEditingController(text: "Shivajinagar, Pune");
  int _chargerCount = 3;
  double _defaultTariff = 18.0;
  String _connectorType = "CCS2 & Type 2";

  void _nextPage() {
    if (_currentStep < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _completeSetup();
    }
  }

  void _completeSetup() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildStep1Identity(),
                  _buildStep2Hardware(),
                  _buildStep3Tariff(),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "STATION PROVISIONING • STEP ${_currentStep + 1} OF 3",
                style: const TextStyle(color: _cyan, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              Text(
                "${((_currentStep + 1) / 3 * 100).toInt()}%",
                style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: _panel,
              valueColor: const AlwaysStoppedAnimation<Color>(_cyan),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // Step 1: Station Identity & GPS
  Widget _buildStep1Identity() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Station Identity", style: TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text("Welcome ${widget.hostName}. Let's configure your charging hub.", style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 24),
          _inputLabel("STATION / HUB NAME"),
          TextField(
            controller: _stationNameController,
            style: const TextStyle(color: _text, fontSize: 13),
            decoration: _inputDecoration("e.g. ABC Motors EV Hub", Icons.ev_station_rounded),
          ),
          const SizedBox(height: 18),
          _inputLabel("PHYSICAL LOCATION / ADDRESS"),
          TextField(
            controller: _locationController,
            style: const TextStyle(color: _text, fontSize: 13),
            decoration: _inputDecoration("e.g. Shivajinagar, Pune", Icons.location_on_outlined),
          ),
        ],
      ),
    );
  }

  // Step 2: Hardware & Chargers
  Widget _buildStep2Hardware() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Charger Inventory", style: TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text("Specify connected hardware for telemetry and queuing.", style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 24),
          _inputLabel("NUMBER OF ACTIVE DISPENSERS"),
          Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(backgroundColor: _panel),
                icon: const Icon(Icons.remove, color: _cyan),
                onPressed: () {
                  if (_chargerCount > 1) setState(() => _chargerCount--);
                },
              ),
              const SizedBox(width: 16),
              Text("$_chargerCount Bays", style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              IconButton(
                style: IconButton.styleFrom(backgroundColor: _panel),
                icon: const Icon(Icons.add, color: _cyan),
                onPressed: () => setState(() => _chargerCount++),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _inputLabel("PRIMARY CONNECTOR STANDARDS"),
          Wrap(
            spacing: 8,
            children: ["CCS2 (DC Fast)", "Type 2 (AC)", "CHAdeMO"].map((standard) {
              final isSelected = _connectorType.contains(standard);
              return FilterChip(
                selected: isSelected,
                backgroundColor: _panel,
                selectedColor: _cyan.withOpacity(0.2),
                label: Text(standard, style: TextStyle(color: isSelected ? _cyan : _muted, fontSize: 11)),
                onSelected: (_) => setState(() => _connectorType = standard),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Step 3: Default Pricing
  Widget _buildStep3Tariff() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tariff & AI Dispatch", style: TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text("Set your baseline price. The AI copilot will suggest dynamic rates later.", style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 30),
          Center(
            child: Column(
              children: [
                Text("₹${_defaultTariff.toStringAsFixed(1)} / kWh", style: const TextStyle(color: _lime, fontSize: 32, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text("Baseline Rate per unit", style: TextStyle(color: _muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Slider(
            value: _defaultTariff,
            min: 10.0,
            max: 35.0,
            divisions: 50,
            activeColor: _lime,
            inactiveColor: _panel,
            onChanged: (val) => setState(() => _defaultTariff = val),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: _panel,
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
              child: const Text("BACK", style: TextStyle(color: _muted, fontWeight: FontWeight.bold)),
            ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentStep == 2 ? _lime : _cyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _nextPage,
            icon: Icon(_currentStep == 2 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded, size: 18),
            label: Text(
              _currentStep == 2 ? "DEPLOY STATION" : "CONTINUE",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: _cyan, size: 18),
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 12),
      filled: true,
      fillColor: _panel,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cyan, width: 1.2)),
    );
  }
}