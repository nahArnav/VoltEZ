import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// DUMMY MODELS & COMPONENT (Self-contained for the Widget Test Suite)
// If you have an existing dashboard_screen.dart, replace this with its import.
// ---------------------------------------------------------------------------

class DashboardKPIs {
  final String totalRevenue;
  final String energyDispensed;
  final int activeChargers;
  final int reliability;

  const DashboardKPIs({
    required this.totalRevenue,
    required this.energyDispensed,
    required this.activeChargers,
    required this.reliability,
  });
}

class DashboardScreen extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final DashboardKPIs? kpis;
  final List<String> recommendations;
  final VoidCallback? onRetry;

  const DashboardScreen({
    super.key,
    this.isLoading = false,
    this.errorMessage,
    this.kpis,
    this.recommendations = const [],
    this.onRetry,
  });

  static const Color bg = Color(0xFF05090E);
  static const Color panel = Color(0xFF0B141C);
  static const Color cyan = Color(0xFF50F5FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Voltez Station Dashboard'),
        backgroundColor: panel,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('dashboard_loading_indicator')),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                key: const Key('dashboard_error_text'),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('dashboard_retry_button'),
                onPressed: onRetry,
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KEY METRICS',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (kpis != null) ...[
            Row(
              children: [
                _buildKpiCard('Total Revenue', kpis!.totalRevenue, Icons.currency_rupee),
                const SizedBox(width: 8),
                _buildKpiCard('Energy Dispensed', '${kpis!.energyDispensed} kWh', Icons.bolt),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildKpiCard('Active Chargers', '${kpis!.activeChargers} Units', Icons.ev_station),
                const SizedBox(width: 8),
                _buildKpiCard('Reliability', '${kpis!.reliability}%', Icons.check_circle),
              ],
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'ACTIVE RECOMMENDATIONS',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...recommendations.map(
            (rec) => Container(
              key: Key('rec_card_${rec.hashCode}'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cyan.withOpacity(0.2)),
              ),
              child: Text(rec, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        key: Key('kpi_card_$title'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cyan, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TEST SUITE
// ---------------------------------------------------------------------------

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('DashboardScreen Widget Tests', () {
    testWidgets('Renders loading indicator when isLoading is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const DashboardScreen(isLoading: true),
        ),
      );

      expect(find.byKey(const Key('dashboard_loading_indicator')), findsOneWidget);
      expect(find.text('KEY METRICS'), findsNothing);
    });

    testWidgets('Renders all KPI metrics, cards, and recommendations correctly on success', (WidgetTester tester) async {
      const kpiData = DashboardKPIs(
        totalRevenue: '₹1,28,640',
        energyDispensed: '1,247',
        activeChargers: 3,
        reliability: 98,
      );

      final recommendations = [
        'Raise evening price to ₹24/kWh to capture surge demand.',
        'Schedule charger #2 maintenance during 02:00-05:00 window.',
      ];

      await tester.pumpWidget(
        createTestWidget(
          DashboardScreen(
            isLoading: false,
            kpis: kpiData,
            recommendations: recommendations,
          ),
        ),
      );

      // Verify Header & Sections
      expect(find.text('Voltez Station Dashboard'), findsOneWidget);
      expect(find.text('KEY METRICS'), findsOneWidget);
      expect(find.text('ACTIVE RECOMMENDATIONS'), findsOneWidget);

      // Verify KPI Metrics
      expect(find.text('₹1,28,640'), findsOneWidget);
      expect(find.text('Total Revenue'), findsOneWidget);

      expect(find.text('1,247 kWh'), findsOneWidget);
      expect(find.text('Energy Dispensed'), findsOneWidget);

      expect(find.text('3 Units'), findsOneWidget);
      expect(find.text('Active Chargers'), findsOneWidget);

      expect(find.text('98%'), findsOneWidget);
      expect(find.text('Reliability'), findsOneWidget);

      // Verify KPI Card Containers
      expect(find.byKey(const Key('kpi_card_Total Revenue')), findsOneWidget);
      expect(find.byKey(const Key('kpi_card_Energy Dispensed')), findsOneWidget);
      expect(find.byKey(const Key('kpi_card_Active Chargers')), findsOneWidget);
      expect(find.byKey(const Key('kpi_card_Reliability')), findsOneWidget);

      // Verify Recommendations List
      expect(find.text(recommendations[0]), findsOneWidget);
      expect(find.text(recommendations[1]), findsOneWidget);
    });

    testWidgets('Renders error state and triggers retry callback on tap', (WidgetTester tester) async {
      bool retryTriggered = false;

      await tester.pumpWidget(
        createTestWidget(
          DashboardScreen(
            isLoading: false,
            errorMessage: 'Failed to connect to Voltez telemetry server (500).',
            onRetry: () {
              retryTriggered = true;
            },
          ),
        ),
      );

      // Verify Error Elements
      expect(find.byKey(const Key('dashboard_error_text')), findsOneWidget);
      expect(find.text('Failed to connect to Voltez telemetry server (500).'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_retry_button')), findsOneWidget);

      // Verify KPI sections are NOT shown during error
      expect(find.text('KEY METRICS'), findsNothing);

      // Tap Retry Button
      await tester.tap(find.byKey(const Key('dashboard_retry_button')));
      await tester.pump();

      expect(retryTriggered, isTrue);
    });
  });
}