import 'package:flutter/material.dart';
import '../../services/business_api.dart'; // Adjust path if needed

const _bg = Color(0xFF05090E);
const _panel = Color(0xFF0B141C);
const _cyan = Color(0xFF50F5FF);
const _lime = Color(0xFFC9FF58);
const _text = Color(0xFFF1F8FF);
const _muted = Color(0xFF7990A1);
const _danger = Color(0xFFFF5F6D);
const _amber = Color(0xFFFFC857);

class AvailabilitySchedulerScreen extends StatefulWidget {
  final BusinessApi api;
  final String? initialChargerId;

  const AvailabilitySchedulerScreen({
    super.key,
    required this.api,
    this.initialChargerId,
  });

  @override
  State<AvailabilitySchedulerScreen> createState() =>
      _AvailabilitySchedulerScreenState();
}

class _AvailabilitySchedulerScreenState
    extends State<AvailabilitySchedulerScreen> {
  List<Charger> _chargers = [];
  String? _selectedChargerId;
  DateTime _selectedDate = DateTime.now();

  Future<List<AvailabilitySlot>>? _slotsFuture;
  List<AvailabilitySlot> _editableSlots = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadChargersAndSlots();
  }

  Future<void> _loadChargersAndSlots() async {
    try {
      final dashboard = await widget.api.loadDashboard();
      if (!mounted) return;
      setState(() {
        _chargers = dashboard.chargers;
        _selectedChargerId = widget.initialChargerId ??
            (_chargers.isNotEmpty ? _chargers.first.id : null);
      });

      if (_selectedChargerId != null) {
        _fetchSlots();
      } else {
        // If no chargers are found, initialize with default empty state
        setState(() {
          _slotsFuture = Future.value([]);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _slotsFuture = Future.value(_generateDefaultSlots());
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _panel,
            content: Text('Failed to load chargers: $e',
                style: const TextStyle(color: _danger)),
          ),
        );
      }
    }
  }

  void _fetchSlots() {
    if (_selectedChargerId == null) return;
    final dateStr =
        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    setState(() {
      _slotsFuture = _fetchSlotsWithFallback(_selectedChargerId!, dateStr);
    });
  }

  Future<List<AvailabilitySlot>> _fetchSlotsWithFallback(
      String chargerId, String dateStr) async {
    try {
      final slots = await widget.api.getAvailabilitySlots(
        chargerId: chargerId,
        date: dateStr,
      );
      _editableSlots = List.from(slots);
      return slots;
    } catch (_) {
      final fallback = _generateDefaultSlots();
      _editableSlots = List.from(fallback);
      return fallback;
    }
  }

  List<AvailabilitySlot> _generateDefaultSlots() {
    final List<AvailabilitySlot> defaults = [];
    for (int hour = 6; hour < 22; hour++) {
      final start = "${hour.toString().padLeft(2, '0')}:00";
      final end = "${(hour + 1).toString().padLeft(2, '0')}:00";
      final isPeak = hour >= 17 && hour <= 21;
      defaults.add(
        AvailabilitySlot(
          id: 'slot_$hour',
          startTime: start,
          endTime: end,
          pricePerKwh: isPeak ? 22.0 : 16.0,
          isAvailable: true,
          isPeak: isPeak,
        ),
      );
    }
    return defaults;
  }

  Future<void> _saveSchedule() async {
    if (_selectedChargerId == null) return;

    setState(() => _isSaving = true);
    final dateStr =
        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    try {
      await widget.api.updateAvailabilitySlots(
        chargerId: _selectedChargerId!,
        date: dateStr,
        slots: _editableSlots,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _panel,
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: _lime, size: 18),
              SizedBox(width: 8),
              Text("Schedule updated successfully",
                  style: TextStyle(color: _text)),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _panel,
            content: Text('Failed to update schedule: $e',
                style: const TextStyle(color: _danger)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPriceEditDialog(int index) {
    final slot = _editableSlots[index];
    final controller =
        TextEditingController(text: slot.pricePerKwh.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _panel,
        title: Text(
          'Edit Slot Rate (${slot.startTime} - ${slot.endTime})',
          style: const TextStyle(color: _text, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: _text),
          decoration: InputDecoration(
            labelText: 'Price per kWh (₹)',
            labelStyle: const TextStyle(color: _muted),
            prefixIcon: const Icon(Icons.currency_rupee, color: _cyan),
            filled: true,
            fillColor: _bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCEL', style: TextStyle(color: _muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _lime,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final newPrice = double.tryParse(controller.text.trim());
              if (newPrice != null && newPrice > 0) {
                setState(() {
                  _editableSlots[index] =
                      slot.copyWith(pricePerKwh: newPrice);
                });
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('APPLY'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildChargerSelector(),
            _buildDatePicker(),
            const SizedBox(height: 12),
            Expanded(
              child: _slotsFuture == null
                  ? const Center(
                      child: CircularProgressIndicator(color: _cyan),
                    )
                  : FutureBuilder<List<AvailabilitySlot>>(
                      future: _slotsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child:
                                  CircularProgressIndicator(color: _cyan));
                        }

                        if (_editableSlots.isEmpty) {
                          return const Center(
                            child: Text(
                              'No slots available for this charger.',
                              style: TextStyle(color: _muted),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(20, 8, 20, 90),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _editableSlots.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final slot = _editableSlots[index];
                            return _buildSlotTile(slot, index);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: _text),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "DISPATCH & TARIFF",
                  style: TextStyle(
                    color: _cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Availability & Pricing",
                  style: TextStyle(
                    color: _text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _fetchSlots,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cyan.withOpacity(.2)),
              ),
              child:
                  const Icon(Icons.refresh_rounded, color: _cyan, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargerSelector() {
    if (_chargers.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: _chargers.map((charger) {
          final isSelected = charger.id == _selectedChargerId;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedChargerId = charger.id);
              _fetchSlots();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? _cyan.withOpacity(0.15)
                    : _panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? _cyan
                      : _cyan.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.ev_station_rounded,
                      size: 16, color: isSelected ? _cyan : _muted),
                  const SizedBox(width: 6),
                  Text(
                    charger.name,
                    style: TextStyle(
                      color: isSelected ? _cyan : _text,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDatePicker() {
    final days =
        List.generate(7, (i) => DateTime.now().add(Duration(days: i)));

    return Container(
      height: 60,
      margin: const EdgeInsets.only(top: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.day == _selectedDate.day &&
              day.month == _selectedDate.month &&
              day.year == _selectedDate.year;

          final weekDay =
              ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day.weekday - 1];

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = day);
              _fetchSlots();
            },
            child: Container(
              width: 52,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? _lime : _panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? _lime
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekDay,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.black87 : _muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${day.day}",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.black : _text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotTile(AvailabilitySlot slot, int index) {
    final isAvailable = slot.isAvailable;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAvailable
              ? (slot.isPeak
                  ? _amber.withOpacity(0.3)
                  : _cyan.withOpacity(0.15))
              : _danger.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${slot.startTime} – ${slot.endTime}",
                style: const TextStyle(
                    color: _text, fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                slot.isPeak ? "PEAK SURGE" : "STANDARD RATE",
                style: TextStyle(
                  color: slot.isPeak ? _amber : _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          InkWell(
            onTap: () => _showPriceEditDialog(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: _cyan.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Text(
                    "₹${slot.pricePerKwh.toStringAsFixed(1)}",
                    style: const TextStyle(
                        color: _cyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_outlined, color: _cyan, size: 13),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: isAvailable,
            activeColor: _lime,
            inactiveThumbColor: _muted,
            inactiveTrackColor: _bg,
            onChanged: (val) {
              setState(() {
                _editableSlots[index] = slot.copyWith(isAvailable: val);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: _panel,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveSchedule,
          style: ElevatedButton.styleFrom(
            backgroundColor: _lime,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(
            _isSaving ? "SAVING..." : "SAVE SCHEDULE & RATES",
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}