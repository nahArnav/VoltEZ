import 'package:flutter/material.dart';

const bg = Color(0xFF05090E);
const panel = Color(0xFF0B141C);
const cyan = Color(0xFF50F5FF);
const lime = Color(0xFFC9FF58);
const violet = Color(0xFF9678FF);
const text = Color(0xFFF1F7FA);
const muted = Color(0xFF7D909D);

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String selectedFilter = 'All';
  final TextEditingController search = TextEditingController();

  final List<Map<String, dynamic>> stations = [
    {
      "name": "VoltHub Central",
      "distance": "1.2 km",
      "price": "₹18/kWh",
      "available": 3,
      "power": "120 kW",
      "type": "CCS2"
    },
    {
      "name": "ChargeGrid West",
      "distance": "2.8 km",
      "price": "₹16/kWh",
      "available": 1,
      "power": "60 kW",
      "type": "CCS2"
    },
    {
      "name": "Electra Point",
      "distance": "4.1 km",
      "price": "₹20/kWh",
      "available": 5,
      "power": "180 kW",
      "type": "Type-2"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _searchBar(),
                    const SizedBox(height: 18),
                    _mapPreview(),
                    const SizedBox(height: 22),
                    const Text(
                      "FILTERS",
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _filters(),
                    const SizedBox(height: 22),
                    Row(
                      children: const [
                        Text(
                          "NEARBY STATIONS",
                          style: TextStyle(
                            color: text,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Text(
                          "3 found",
                          style: TextStyle(color: cyan),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...stations.map((e) => _stationCard(e)).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Row(
        children: const [
          Icon(Icons.map_rounded, color: cyan, size: 26),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "EXPLORE",
                style: TextStyle(
                  color: text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                "Nearby charging stations",
                style: TextStyle(color: muted, fontSize: 11),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: search,
        style: const TextStyle(color: text),
        decoration: const InputDecoration(
          hintText: "Search station or area...",
          hintStyle: TextStyle(color: muted),
          prefixIcon: Icon(Icons.search, color: cyan),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _mapPreview() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: panel,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: GridPainter(),
              ),
            ),
          ),
          const Center(
            child: Icon(Icons.location_pin, color: cyan, size: 40),
          ),
          Positioned(
            left: 40,
            top: 55,
            child: _pin(),
          ),
          Positioned(
            right: 70,
            bottom: 50,
            child: _pin(),
          ),
          Positioned(
            left: 120,
            bottom: 30,
            child: _pin(),
          ),
          const Positioned(
            bottom: 12,
            right: 12,
            child: Icon(Icons.my_location, color: lime),
          )
        ],
      ),
    );
  }

  Widget _pin() => Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: cyan,
          shape: BoxShape.circle,
        ),
      );

  Widget _filters() {
    final items = ["All", "Fast", "Available", "CCS2"];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final active = selectedFilter == item;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => selectedFilter = item),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: active ? cyan.withOpacity(.15) : panel,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: active ? cyan : Colors.white12,
                  ),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    color: active ? cyan : muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _stationCard(Map<String, dynamic> s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cyan.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.ev_station,
                  color: cyan,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s["name"],
                      style: const TextStyle(
                        color: text,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s["distance"],
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                      ),
                    )
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: lime.withOpacity(.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${s["available"]} Free",
                  style: const TextStyle(
                    color: lime,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _info(Icons.flash_on, s["power"]),
              const SizedBox(width: 14),
              _info(Icons.electrical_services, s["type"]),
              const Spacer(),
              Text(
                s["price"],
                style: const TextStyle(
                  color: cyan,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {},
              child: const Text(
                "BOOK CHARGER",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _info(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: violet, size: 16),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(color: text, fontSize: 11),
        )
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cyan.withOpacity(.06)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}