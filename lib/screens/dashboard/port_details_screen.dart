import 'package:flutter/material.dart';
import '../../services/business_api.dart';
import 'availability_scheduler_screen.dart';

const _bg = Color(0xFF05090E);
const _panel = Color(0xFF0B141C);
const _cyan = Color(0xFF50F5FF);
const _lime = Color(0xFFC9FF58);
const _text = Color(0xFFF1F8FF);
const _muted = Color(0xFF7990A1);
const _danger = Color(0xFFFF5F6D);
const _amber = Color(0xFFFFC857);

class PortDetailsScreen extends StatefulWidget {
  final String chargerName;
  final BusinessApi api;

  PortDetailsScreen({
    super.key,
    required this.chargerName,
    BusinessApi? api,
  }) : api = api ??
            BusinessApi(
              baseUrl: 'https://api.yourdomain.com',
              getAuthToken: () => '',
            );

  @override
  State<PortDetailsScreen> createState() => _PortDetailsScreenState();
}

class _PortDetailsScreenState extends State<PortDetailsScreen> {
  late Future<BusinessSnapshot> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  void _fetchDetails() {
    setState(() {
      _dashboardFuture = widget.api.loadDashboard();
    });
  }

  Color _portStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return _lime;
      case 'occupied':
      case 'in use':
        return _cyan;
      case 'offline':
      default:
        return _danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "CONNECTOR SPECIFICATIONS",
              style: TextStyle(
                color: _cyan,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.chargerName,
              style: const TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Manage Rates & Schedule",
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _lime.withValues(alpha: .3)),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: _lime, size: 18),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AvailabilitySchedulerScreen(
                    api: widget.api,
                    initialChargerId: widget.chargerName,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<BusinessSnapshot>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _cyan),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: _danger, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      "Failed to load charger details:\n${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _fetchDetails,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _cyan,
                        side: const BorderSide(color: _cyan),
                      ),
                      child: const Text("RETRY"),
                    ),
                  ],
                ),
              ),
            );
          }

          final chargers = snapshot.data?.chargers ?? [];
          final charger = chargers.firstWhere(
            (c) => c.name.toLowerCase() == widget.chargerName.toLowerCase(),
            orElse: () => Charger(
              id: 'unknown',
              name: widget.chargerName,
              power: 60,
              status: 'active',
              reliability: 0.95,
              ports: [
                const Port(name: 'CCS2', status: 'available'),
                const Port(name: 'Type 2', status: 'occupied'),
              ],
            ),
          );

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewBanner(charger),
                const SizedBox(height: 24),
                const Text(
                  "ACTIVE PORTS & GUNS",
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...charger.ports
                    .map((port) => _buildPortCard(port, charger))
                    ,
                const SizedBox(height: 24),
                _buildScheduleShortcutCard(charger),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewBanner(Charger charger) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cyan.withValues(alpha: .15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCol("MAX OUTPUT", "${charger.power} kW", _cyan),
          Container(
              height: 30, width: 1, color: Colors.white.withValues(alpha: .08)),
          _buildStatCol("HEALTH",
              "${(charger.reliability * 100).toStringAsFixed(0)}%", _lime),
          Container(
              height: 30, width: 1, color: Colors.white.withValues(alpha: .08)),
          _buildStatCol(
              "TOTAL PORTS", "${charger.ports.length}", _text),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String val, Color color) {
    return Column(
      children: [
        Text(val,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                color: _muted,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      ],
    );
  }

  Widget _buildPortCard(Port port, Charger charger) {
    final statusCol = _portStatusColor(port.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusCol.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusCol.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.power_rounded, color: statusCol, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  port.name,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Connector Protocol • Fast DC",
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusCol.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              port.status.toUpperCase(),
              style: TextStyle(
                color: statusCol,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleShortcutCard(Charger charger) {
    return InkWell(
      onTap: () {
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _lime.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _lime.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, color: _lime, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Configure Rates & Availability",
                    style: TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Set peak hours, dynamic pricing and time slots",
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: _lime, size: 14),
          ],
        ),
      ),
    );
  }
}