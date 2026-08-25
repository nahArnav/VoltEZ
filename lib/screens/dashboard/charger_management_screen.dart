import 'package:flutter/material.dart';
import 'port_details_screen.dart';
import 'availability_scheduler_screen.dart';
import '../chargers/add_edit_chargers_screen.dart';
import '../../services/business_api.dart';

const Color _bg = Color(0xFF05090E);
const Color _panel = Color(0xFF0B141C);
const Color _cyan = Color(0xFF50F5FF);
const Color _lime = Color(0xFFC9FF58);
const Color _violet = Color(0xFF9678FF);
const Color _text = Color(0xFFF1F8FF);
const Color _muted = Color(0xFF7990A1);
const Color _danger = Color(0xFFFF5F6D);
const Color _amber = Color(0xFFFFC857);

class ChargerManagementScreen extends StatefulWidget {
  final BusinessApi api;

  ChargerManagementScreen({
    super.key,
    BusinessApi? api,
  }) : api = api ??
            BusinessApi(
              baseUrl: 'https://api.yourdomain.com',
              getAuthToken: () => '',
            );

  @override
  State<ChargerManagementScreen> createState() =>
      _ChargerManagementScreenState();
}

class _ChargerManagementScreenState extends State<ChargerManagementScreen> {
  late Future<List<Charger>> _chargersFuture;
  List<Charger> _allChargers = [];
  String _searchQuery = '';
  final Set<String> _updatingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchChargers();
  }

  void _fetchChargers() {
    setState(() {
      _chargersFuture = _loadData();
    });
  }

  Future<List<Charger>> _loadData() async {
    final snapshot = await widget.api.loadDashboard();
    _allChargers = snapshot.chargers;
    return snapshot.chargers;
  }

  Future<void> _toggleChargerStatus(Charger charger) async {
    final newStatus =
        charger.status.toLowerCase() == 'active' ? 'paused' : 'active';

    setState(() => _updatingIds.add(charger.id));

    try {
      await widget.api.updateChargerStatus(charger.id, newStatus);

      final index = _allChargers.indexWhere((c) => c.id == charger.id);
      if (index != -1) {
        setState(() {
          _allChargers[index] = Charger(
            id: charger.id,
            name: charger.name,
            power: charger.power,
            status: newStatus,
            reliability: charger.reliability,
            ports: charger.ports,
          );
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _panel,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: _lime, size: 18),
                const SizedBox(width: 8),
                Text(
                  "${charger.name} is now ${newStatus.toUpperCase()}",
                  style: const TextStyle(color: _text),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _panel,
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: _danger, size: 18),
                const SizedBox(width: 8),
                Text("Failed to update status: $e",
                    style: const TextStyle(color: _text)),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingIds.remove(charger.id));
      }
    }
  }

  void _deleteCharger(Charger charger, int index) {
    setState(() => _allChargers.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _panel,
        content: Text("${charger.name} removed from bay list.",
            style: const TextStyle(color: _danger)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: _cyan,
          onPressed: () => setState(() => _allChargers.insert(index, charger)),
        ),
      ),
    );
  }

  void _showEditBayModal(Charger charger, int index) {
    final nameCtrl = TextEditingController(text: charger.name);
    final powerCtrl = TextEditingController(text: charger.power.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: _cyan, size: 22),
                const SizedBox(width: 10),
                const Text(
                  "Edit Hardware Spec",
                  style: TextStyle(
                      color: _text, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: _muted),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: _text, fontSize: 13),
              decoration: InputDecoration(
                labelText: "CHARGER BAY LABEL",
                labelStyle: const TextStyle(color: _muted, fontSize: 10),
                prefixIcon:
                    const Icon(Icons.label_outline_rounded, color: _cyan, size: 18),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: powerCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: _text, fontSize: 13),
              decoration: InputDecoration(
                labelText: "POWER CAPACITY (KW)",
                labelStyle: const TextStyle(color: _muted, fontSize: 10),
                prefixIcon: const Icon(Icons.bolt_rounded, color: _cyan, size: 18),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _lime,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final newPower = int.tryParse(powerCtrl.text.trim()) ?? charger.power;
                  setState(() {
                    _allChargers[index] = Charger(
                      id: charger.id,
                      name: nameCtrl.text.trim(),
                      power: newPower,
                      status: charger.status,
                      reliability: charger.reliability,
                      ports: charger.ports,
                    );
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: _panel,
                      content: Text("Charger specs updated successfully!",
                          style: TextStyle(color: _lime)),
                    ),
                  );
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text(
                  "SAVE BAY CONFIGURATION",
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case "active":
        return _lime;
      case "paused":
        return _amber;
      case "offline":
        return _danger;
      default:
        return _muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearch(),
            const SizedBox(height: 14),
            Expanded(
              child: RefreshIndicator(
                color: _cyan,
                backgroundColor: _panel,
                onRefresh: () async => _fetchChargers(),
                child: FutureBuilder<List<Charger>>(
                  future: _chargersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _cyan),
                      );
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState(snapshot.error.toString());
                    }

                    final filteredChargers = _allChargers.where((c) {
                      final query = _searchQuery.toLowerCase();
                      return c.name.toLowerCase().contains(query) ||
                          c.status.toLowerCase().contains(query) ||
                          c.ports.any((p) =>
                              p.name.toLowerCase().contains(query) ||
                              p.status.toLowerCase().contains(query));
                    }).toList();

                    if (filteredChargers.isEmpty) {
                      return _buildEmptyState();
                    }

                    final totalPower = _allChargers.fold<int>(
                        0, (sum, c) => sum + c.power);
                    final onlineCount = _allChargers
                        .where((c) => c.status.toLowerCase() == 'active')
                        .length;

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                      itemCount: filteredChargers.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildCapacityHero(onlineCount, totalPower),
                          );
                        }
                        final chargerIndex = index - 1;
                        return _buildChargerCard(
                            filteredChargers[chargerIndex], chargerIndex);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _lime,
        foregroundColor: Colors.black,
        elevation: 0,
        onPressed: () async {
          final result = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(builder: (_) => const AddEditChargerScreen()),
          );
          if (result != null) {
            _fetchChargers();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: _panel,
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: _lime),
                      const SizedBox(width: 10),
                      Text(
                        "Charger ${result['name']} saved successfully",
                        style: const TextStyle(color: _text),
                      ),
                    ],
                  ),
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          "ADD CHARGER",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
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
                  "CHARGER NETWORK",
                  style: TextStyle(
                    color: _cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Charger Fleet",
                  style: TextStyle(
                    color: _text,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _fetchChargers,
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cyan.withOpacity(.18)),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: _cyan,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(color: _text),
        decoration: InputDecoration(
          hintText: "Search charger bays, connector ports...",
          hintStyle: const TextStyle(color: _muted, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded, color: _cyan),
          filled: true,
          fillColor: _panel,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _cyan.withOpacity(.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _cyan.withOpacity(.08)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: _cyan),
          ),
        ),
      ),
    );
  }

  Widget _buildCapacityHero(int onlineCount, int totalPower) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cyan.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "TOTAL STATION CAPACITY",
                  style: TextStyle(
                      color: _muted,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  "$totalPower kW Power",
                  style: const TextStyle(
                      color: _text, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  "$onlineCount of ${_allChargers.length} Dispensers Active",
                  style: const TextStyle(
                      color: _lime, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _cyan.withOpacity(0.08),
              border: Border.all(color: _cyan.withOpacity(0.25)),
            ),
            child: const Icon(Icons.bolt_rounded, color: _cyan, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildChargerCard(Charger charger, int index) {
    final String status = charger.status;
    final Color color = statusColor(status);
    final bool isUpdating = _updatingIds.contains(charger.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chargerIcon(color),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      charger.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "ID: ${charger.id} • ${charger.ports.length} Port(s)",
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(status, color),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: Colors.white.withOpacity(.06),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _metric(
                "${charger.power}",
                "kW POWER",
                Icons.bolt_rounded,
                _cyan,
              ),
              _metric(
                "${charger.ports.length}",
                "PORTS",
                Icons.power_rounded,
                _text,
              ),
              _metric(
                "${(charger.reliability * 100).toStringAsFixed(0)}%",
                "RELIABILITY",
                Icons.favorite_outline_rounded,
                _lime,
              ),
            ],
          ),
          if (charger.ports.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: charger.ports.map((p) => _portBadge(p)).toList(),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PortDetailsScreen(
                          chargerName: charger.name,
                          api: widget.api,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cyan,
                    side: BorderSide(color: _cyan.withOpacity(.4)),
                    minimumSize: const Size.fromHeight(38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "DETAILS",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AvailabilitySchedulerScreen(
                          api: widget.api,
                          initialChargerId: charger.id,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _lime,
                    side: BorderSide(color: _lime.withOpacity(.4)),
                    minimumSize: const Size.fromHeight(38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "RATES & SLOTS",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () => _toggleChargerStatus(charger),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        status.toLowerCase() == "active" ? _amber : _lime,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isUpdating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          status.toLowerCase() == "active"
                              ? "PAUSE"
                              : "RESUME",
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showEditBayModal(charger, index),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _violet,
                    side: BorderSide(color: _violet.withOpacity(.4)),
                    minimumSize: const Size.fromHeight(38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "EDIT HARDWARE",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: _danger, size: 18),
                onPressed: () => _deleteCharger(charger, index),
                tooltip: "Delete bay",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chargerIcon(Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Icon(
        Icons.ev_station_rounded,
        color: color,
        size: 24,
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: _text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _portBadge(Port port) {
    Color portColor;
    switch (port.status.toLowerCase()) {
      case 'available':
        portColor = _lime;
        break;
      case 'occupied':
        portColor = _cyan;
        break;
      case 'offline':
      default:
        portColor = _muted;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.035),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: portColor.withOpacity(.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: portColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            "${port.name} (${port.status})",
            style: const TextStyle(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: _danger),
            const SizedBox(height: 12),
            const Text(
              "Failed to load chargers",
              style: TextStyle(
                  color: _text, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _fetchChargers,
              style: OutlinedButton.styleFrom(
                foregroundColor: _cyan,
                side: const BorderSide(color: _cyan),
              ),
              child: const Text("RETRY"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ev_station_rounded, size: 48, color: _muted),
          SizedBox(height: 12),
          Text(
            "No chargers found",
            style: TextStyle(
                color: _text, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          SizedBox(height: 4),
          Text(
            "Try adjusting your search query.",
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}