import 'package:flutter/material.dart';

const _bg = Color(0xFF05090E);
const _panel = Color(0xFF0B141C);
const _cyan = Color(0xFF50F5FF);
const _lime = Color(0xFFC9FF58);
const _violet = Color(0xFF9678FF);
const _text = Color(0xFFF1F8FF);
const _muted = Color(0xFF7990A1);
const _amber = Color(0xFFFFC857);
const _danger = Color(0xFFFF5F6D);

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String selectedFilter = "ALL";

  final List<Map<String, dynamic>> bookings = [
    {
      "id": "VLT-1042",
      "customer": "Rahul Sharma",
      "vehicle": "Tata Nexon EV",
      "charger": "Charger 01",
      "time": "10:00 AM – 11:30 AM",
      "date": "Today",
      "energy": 32.5,
      "amount": 601.25,
      "status": "CONFIRMED",
    },
    {
      "id": "VLT-1043",
      "customer": "Aarav Mehta",
      "vehicle": "MG ZS EV",
      "charger": "Charger 02",
      "time": "12:30 PM – 02:00 PM",
      "date": "Today",
      "energy": 27.8,
      "amount": 417.0,
      "status": "UPCOMING",
    },
    {
      "id": "VLT-1044",
      "customer": "Priya Deshmukh",
      "vehicle": "Hyundai Ioniq 5",
      "charger": "Charger 01",
      "time": "03:00 PM – 04:30 PM",
      "date": "Today",
      "energy": 41.2,
      "amount": 762.2,
      "status": "UPCOMING",
    },
    {
      "id": "VLT-1045",
      "customer": "Karan Patel",
      "vehicle": "BYD Atto 3",
      "charger": "Fast Charger Pro",
      "time": "06:00 PM – 07:00 PM",
      "date": "Today",
      "energy": 38.6,
      "amount": 965.0,
      "status": "PENDING",
    },
    {
      "id": "VLT-1040",
      "customer": "Neha Kulkarni",
      "vehicle": "Mahindra XUV400",
      "charger": "Ground Charger 02",
      "time": "09:30 AM – 10:30 AM",
      "date": "Yesterday",
      "energy": 24.4,
      "amount": 366.0,
      "status": "COMPLETED",
    },
    {
      "id": "VLT-1039",
      "customer": "Aditya Joshi",
      "vehicle": "Tata Tiago EV",
      "charger": "Charger 03",
      "time": "05:00 PM – 06:00 PM",
      "date": "Yesterday",
      "energy": 19.2,
      "amount": 288.0,
      "status": "CANCELLED",
    },
  ];

  List<Map<String, dynamic>> get filteredBookings {
    if (selectedFilter == "ALL") {
      return bookings;
    }

    return bookings
        .where((booking) => booking["status"] == selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSummary(),
            _buildFilters(),
            const SizedBox(height: 14),
            Expanded(
              child: filteredBookings.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        30,
                      ),
                      itemCount: filteredBookings.length,
                      itemBuilder: (context, index) {
                        return _buildBookingCard(
                          filteredBookings[index],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _cyan.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _cyan.withValues(alpha: .18),
              ),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: _cyan,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "BOOKING NETWORK",
                  style: TextStyle(
                    color: _cyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Bookings",
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: Colors.white.withValues(alpha: .07),
              ),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: _muted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              "24",
              "TODAY",
              Icons.calendar_today_rounded,
              _cyan,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              "₹18.4K",
              "REVENUE",
              Icons.currency_rupee_rounded,
              _lime,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              "76%",
              "UTILIZATION",
              Icons.bolt_rounded,
              _violet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: .12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            icon,
            color: color,
            size: 17,
          ),
          Text(
            value,
            style: const TextStyle(
              color: _text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    const filters = [
      "ALL",
      "CONFIRMED",
      "UPCOMING",
      "PENDING",
      "COMPLETED",
      "CANCELLED",
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? _cyan.withValues(alpha: .12)
                    : _panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? _cyan.withValues(alpha: .5)
                      : Colors.white.withValues(alpha: .06),
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: selected ? _cyan : _muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // BOOKING CARD
  // ============================================================

  Widget _buildBookingCard(
    Map<String, dynamic> booking,
  ) {
    final status = booking["status"] as String;
    final statusColor = _statusColor(status);

    return GestureDetector(
      onTap: () => _showBookingDetails(booking),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: statusColor.withValues(alpha: .14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP
            Row(
              children: [
                _vehicleIcon(statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking["customer"],
                        style: const TextStyle(
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking["vehicle"],
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(
                  status,
                  statusColor,
                ),
              ],
            ),

            const SizedBox(height: 17),

            Container(
              height: 1,
              color: Colors.white.withValues(alpha: .06),
            ),

            const SizedBox(height: 15),

            // DATE / TIME
            Row(
              children: [
                Expanded(
                  child: _detailItem(
                    Icons.calendar_today_rounded,
                    booking["date"],
                  ),
                ),
                Expanded(
                  child: _detailItem(
                    Icons.schedule_rounded,
                    booking["time"],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // CHARGER
            Row(
              children: [
                const Icon(
                  Icons.ev_station_rounded,
                  color: _cyan,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Text(
                  booking["charger"],
                  style: const TextStyle(
                    color: _text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  booking["id"],
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // BOTTOM METRICS
            Row(
              children: [
                Expanded(
                  child: _smallMetric(
                    "ENERGY",
                    "${booking["energy"]} kWh",
                  ),
                ),
                Expanded(
                  child: _smallMetric(
                    "AMOUNT",
                    "₹${booking["amount"]}",
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _muted,
                  size: 20,
                ),
              ],
            ),

            // ACTIONS
            if (status == "PENDING" ||
                status == "UPCOMING") ...[
              const SizedBox(height: 15),
              Row(
                children: [
                  if (status == "PENDING")
                    Expanded(
                      child: _actionButton(
                        "CONFIRM",
                        _lime,
                        () {
                          setState(() {
                            booking["status"] =
                                "CONFIRMED";
                          });

                          _showMessage(
                            "Booking confirmed",
                            _lime,
                          );
                        },
                      ),
                    ),
                  if (status == "PENDING")
                    const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      "CANCEL",
                      _danger,
                      () {
                        _cancelBooking(booking);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMPONENTS
  // ============================================================

  Widget _vehicleIcon(Color color) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: .16),
        ),
      ),
      child: Icon(
        Icons.electric_car_rounded,
        color: color,
        size: 23,
      ),
    );
  }

  Widget _statusBadge(
    String status,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
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
            status,
            style: TextStyle(
              color: color,
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(
    IconData icon,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: _muted,
          size: 15,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _text,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _smallMetric(
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
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: _text,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    String text,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
            color: color.withValues(alpha: .35),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "CONFIRMED":
        return _cyan;
      case "UPCOMING":
        return _violet;
      case "PENDING":
        return _amber;
      case "COMPLETED":
        return _lime;
      case "CANCELLED":
        return _danger;
      default:
        return _muted;
    }
  }

  // ============================================================
  // BOOKING DETAILS
  // ============================================================

  void _showBookingDetails(
    Map<String, dynamic> booking,
  ) {
    final status = booking["status"] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            30,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: _cyan,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Booking Details",
                    style: TextStyle(
                      color: _text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              _bottomDetail(
                "BOOKING ID",
                booking["id"],
              ),
              _bottomDetail(
                "CUSTOMER",
                booking["customer"],
              ),
              _bottomDetail(
                "VEHICLE",
                booking["vehicle"],
              ),
              _bottomDetail(
                "CHARGER",
                booking["charger"],
              ),
              _bottomDetail(
                "DATE",
                booking["date"],
              ),
              _bottomDetail(
                "TIME",
                booking["time"],
              ),
              _bottomDetail(
                "ENERGY",
                "${booking["energy"]} kWh",
              ),
              _bottomDetail(
                "TOTAL AMOUNT",
                "₹${booking["amount"]}",
              ),
              _bottomDetail(
                "STATUS",
                status,
                valueColor: _statusColor(status),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cyan,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "DONE",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomDetail(
    String label,
    String value, {
    Color valueColor = _text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CANCEL
  // ============================================================

  void _cancelBooking(
    Map<String, dynamic> booking,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            "Cancel Booking?",
            style: TextStyle(
              color: _text,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            "This booking will be marked as cancelled.",
            style: TextStyle(
              color: _muted,
              fontSize: 12,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                "KEEP",
                style: TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  booking["status"] = "CANCELLED";
                });

                Navigator.pop(dialogContext);

                _showMessage(
                  "Booking cancelled",
                  _danger,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                "CANCEL BOOKING",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy_rounded,
            color: _muted.withValues(alpha: .5),
            size: 48,
          ),
          const SizedBox(height: 14),
          const Text(
            "No bookings found",
            style: TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Try selecting another filter.",
            style: TextStyle(
              color: _muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(
    String message,
    Color color,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _panel,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 9),
            Text(
              message,
              style: const TextStyle(
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}