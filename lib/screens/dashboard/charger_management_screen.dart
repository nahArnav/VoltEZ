import 'package:flutter/material.dart';
import 'port_details_screen.dart';

const _bg = Color(0xFF05090E);
const _panel = Color(0xFF0B141C);
const _cyan = Color(0xFF50F5FF);
const _lime = Color(0xFFC9FF58);
const _violet = Color(0xFF9678FF);
const _text = Color(0xFFF1F8FF);
const _muted = Color(0xFF7990A1);
const _danger = Color(0xFFFF5F6D);
const _amber = Color(0xFFFFC857);

class ChargerManagementScreen extends StatefulWidget {
  const ChargerManagementScreen({super.key});

  @override
  State<ChargerManagementScreen> createState() =>
      _ChargerManagementScreenState();
}

class _ChargerManagementScreenState
    extends State<ChargerManagementScreen> {
  // ============================================================
  // CHARGER DATA
  // ============================================================

  final List<Map<String, dynamic>> chargers = [
    {
      "name": "Basement Charger A",
      "power": 60,
      "price": 18.5,
      "status": "active",
      "reliability": 87,
      "parking": "B2 • Near Elevator",
      "amenities": ["WiFi", "Food", "Restroom"],
    },
    {
      "name": "Ground Charger 02",
      "power": 30,
      "price": 15.0,
      "status": "paused",
      "reliability": 72,
      "parking": "Entrance Gate",
      "amenities": ["Cafe"],
    },
    {
      "name": "Fast Charger Pro",
      "power": 120,
      "price": 25.0,
      "status": "active",
      "reliability": 96,
      "parking": "VIP Zone",
      "amenities": ["WiFi", "Parking"],
    },
  ];

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color statusColor(String status) {
    switch (status) {
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,

      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            _buildSearch(),

            const SizedBox(height: 18),

            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  110,
                ),
                itemCount: chargers.length,
                itemBuilder: (context, index) {
                  return _buildChargerCard(
                    chargers[index],
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ========================================================
      // ADD CHARGER BUTTON
      // ========================================================

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _lime,
        foregroundColor: Colors.black,
        elevation: 0,

        onPressed: _showAddChargerDialog,

        icon: const Icon(
          Icons.add_rounded,
        ),

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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        14,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _text,
            ),
          ),

          const SizedBox(width: 4),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                color: _cyan.withValues(
                  alpha: .18,
                ),
              ),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: _cyan,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: TextField(
        style: const TextStyle(
          color: _text,
        ),
        decoration: InputDecoration(
          hintText: "Search charger network...",

          hintStyle: const TextStyle(
            color: _muted,
            fontSize: 12,
          ),

          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _cyan,
          ),

          filled: true,

          fillColor: _panel,

          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(14),
            borderSide: BorderSide(
              color: _cyan.withValues(
                alpha: .08,
              ),
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(14),
            borderSide: BorderSide(
              color: _cyan.withValues(
                alpha: .08,
              ),
            ),
          ),

          focusedBorder:
              const OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(14),
            ),
            borderSide: BorderSide(
              color: _cyan,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CHARGER CARD
  // ============================================================

  Widget _buildChargerCard(
    Map<String, dynamic> charger,
  ) {
    final String status =
        charger["status"] as String;

    final Color color =
        statusColor(status);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),

      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: _panel,

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color: color.withValues(
            alpha: .16,
          ),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          // ==================================================
          // TOP SECTION
          // ==================================================

          Row(
            children: [
              _chargerIcon(color),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      charger["name"],
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      charger["parking"],
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              _statusBadge(
                status,
                color,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            height: 1,
            color: Colors.white.withValues(
              alpha: .06,
            ),
          ),

          const SizedBox(height: 17),

          // ==================================================
          // METRICS
          // ==================================================

          Row(
            children: [
              _metric(
                "${charger["power"]}",
                "kW POWER",
                Icons.bolt_rounded,
                _cyan,
              ),

              _metric(
                "₹${charger["price"]}",
                "PER kWh",
                Icons.currency_rupee_rounded,
                _text,
              ),

              _metric(
                "${charger["reliability"]}%",
                "HEALTH",
                Icons.favorite_outline_rounded,
                _lime,
              ),
            ],
          ),

          const SizedBox(height: 17),

          // ==================================================
          // AMENITIES
          // ==================================================

          if ((charger["amenities"] as List)
              .isNotEmpty)
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final amenity
                    in charger["amenities"])
                  _amenity(
                    amenity.toString(),
                  ),
              ],
            ),

          const SizedBox(height: 18),

          // ==================================================
          // ACTION BUTTONS
          // ==================================================

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PortDetailsScreen(
                          chargerName:
                              charger["name"],
                        ),
                      ),
                    );
                  },

                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor: _cyan,

                    side: BorderSide(
                      color: _cyan.withValues(
                        alpha: .4,
                      ),
                    ),

                    minimumSize:
                        const Size.fromHeight(
                      44,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        11,
                      ),
                    ),
                  ),

                  child: const Text(
                    "VIEW DETAILS",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 9),

              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      charger["status"] =
                          status == "active"
                              ? "paused"
                              : "active";
                    });
                  },

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        status == "active"
                            ? _amber
                            : _lime,

                    foregroundColor:
                        Colors.black,

                    elevation: 0,

                    minimumSize:
                        const Size.fromHeight(
                      44,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        11,
                      ),
                    ),
                  ),

                  child: Text(
                    status == "active"
                        ? "PAUSE"
                        : "RESUME",

                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHARGER ICON
  // ============================================================

  Widget _chargerIcon(Color color) {
    return Container(
      width: 50,
      height: 50,

      decoration: BoxDecoration(
        color: color.withValues(
          alpha: .08,
        ),

        borderRadius:
            BorderRadius.circular(14),

        border: Border.all(
          color: color.withValues(
            alpha: .2,
          ),
        ),
      ),

      child: Icon(
        Icons.ev_station_rounded,
        color: color,
        size: 25,
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(
    String status,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: color.withValues(
          alpha: .08,
        ),

        borderRadius:
            BorderRadius.circular(8),
      ),

      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,

            decoration:
                BoxDecoration(
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
              fontWeight:
                  FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // METRIC
  // ============================================================

  Widget _metric(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 19,
          ),

          const SizedBox(height: 6),

          Text(
            value,
            style: const TextStyle(
              color: _text,
              fontSize: 15,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 7,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AMENITY
  // ============================================================

  Widget _amenity(String text) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: .035,
        ),

        borderRadius:
            BorderRadius.circular(8),
      ),

      child: Text(
        text,
        style: const TextStyle(
          color: _muted,
          fontSize: 9,
          fontWeight:
              FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // ADD CHARGER DIALOG
  // ============================================================

  void _showAddChargerDialog() {
    final nameController =
        TextEditingController();

    final powerController =
        TextEditingController();

    final priceController =
        TextEditingController();

    final parkingController =
        TextEditingController();

    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _panel,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),

          title: const Text(
            "Add Charger",
            style: TextStyle(
              color: _text,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          content:
              SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [

                // NAME
                _addField(
                  nameController,
                  "Charger Name",
                  Icons.ev_station_rounded,
                ),

                const SizedBox(height: 12),

                // POWER
                _addField(
                  powerController,
                  "Power (kW)",
                  Icons.bolt_rounded,
                  keyboardType:
                      TextInputType.number,
                ),

                const SizedBox(height: 12),

                // PRICE
                _addField(
                  priceController,
                  "Price per kWh",
                  Icons.currency_rupee_rounded,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                ),

                const SizedBox(height: 12),

                // PARKING
                _addField(
                  parkingController,
                  "Parking Location",
                  Icons.location_on_outlined,
                ),
              ],
            ),
          ),

          actions: [

            // CANCEL
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child: const Text(
                "CANCEL",
                style: TextStyle(
                  color: _muted,
                ),
              ),
            ),

            // ADD
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: _lime,
                foregroundColor:
                    Colors.black,
              ),

              onPressed: () {

                // VALIDATION
                if (nameController.text
                        .trim()
                        .isEmpty ||
                    powerController.text
                        .trim()
                        .isEmpty ||
                    priceController.text
                        .trim()
                        .isEmpty) {

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Please enter charger name, power and price.",
                      ),
                    ),
                  );

                  return;
                }

                final int power =
                    int.tryParse(
                          powerController
                              .text
                              .trim(),
                        ) ??
                        0;

                final double price =
                    double.tryParse(
                          priceController
                              .text
                              .trim(),
                        ) ??
                        0;

                if (power <= 0 ||
                    price <= 0) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Power and price must be greater than 0.",
                      ),
                    ),
                  );

                  return;
                }

                // ADD CHARGER
                setState(() {
                  chargers.add({
                    "name":
                        nameController.text
                            .trim(),

                    "power": power,

                    "price": price,

                    "status": "active",

                    "reliability": 100,

                    "parking":
                        parkingController
                                .text
                                .trim()
                                .isEmpty
                            ? "Location not specified"
                            : parkingController
                                .text
                                .trim(),

                    "amenities": [],
                  });
                });

                // CLOSE DIALOG
                Navigator.pop(
                  dialogContext,
                );

                // SUCCESS MESSAGE
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  SnackBar(
                    backgroundColor:
                        _panel,

                    content: const Row(
                      children: [
                        Icon(
                          Icons
                              .check_circle_rounded,
                          color: _lime,
                        ),

                        SizedBox(width: 10),

                        Text(
                          "Charger added successfully",
                          style: TextStyle(
                            color: _text,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },

              child: const Text(
                "ADD CHARGER",
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ADD CHARGER TEXT FIELD
  // ============================================================

  Widget _addField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboardType =
        TextInputType.text,
  }) {
    return TextField(
      controller: controller,

      keyboardType: keyboardType,

      style: const TextStyle(
        color: _text,
        fontSize: 13,
      ),

      decoration:
          InputDecoration(
        hintText: hint,

        hintStyle:
            const TextStyle(
          color: _muted,
          fontSize: 12,
        ),

        prefixIcon:
            Icon(
          icon,
          color: _cyan,
          size: 19,
        ),

        filled: true,

        fillColor: _bg,

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            11,
          ),
          borderSide:
              BorderSide.none,
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            11,
          ),
          borderSide:
              BorderSide.none,
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            11,
          ),
          borderSide:
              const BorderSide(
            color: _cyan,
          ),
        ),
      ),
    );
  }
}