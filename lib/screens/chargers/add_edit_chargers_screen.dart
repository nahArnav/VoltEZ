import 'package:flutter/material.dart';

const bg = Color(0xFF05090E);
const panel = Color(0xFF0B141C);
const cyan = Color(0xFF50F5FF);
const lime = Color(0xFFC9FF58);
const text = Color(0xFFF1F7FA);
const muted = Color(0xFF7D909D);

class AddEditChargerScreen extends StatefulWidget {
  const AddEditChargerScreen({super.key});

  @override
  State<AddEditChargerScreen> createState() =>
      _AddEditChargerScreenState();
}

class _AddEditChargerScreenState
    extends State<AddEditChargerScreen> {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final priceController = TextEditingController();

  String connector = "CCS2";
  String power = "120";
  bool available = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: const BackButton(color: text),
        title: const Text(
          "Add Charger",
          style: TextStyle(color: text),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section("CHARGER INFORMATION"),

            _field(
              controller: nameController,
              label: "Station Name",
              hint: "VoltHub Central",
              icon: Icons.ev_station,
            ),

            const SizedBox(height: 16),

            _field(
              controller: addressController,
              label: "Location",
              hint: "Shivajinagar, Pune",
              icon: Icons.location_on,
            ),

            const SizedBox(height: 24),

            _section("CONNECTOR"),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _choice(
                    "CCS2",
                    connector,
                    (v) => setState(() => connector = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _choice(
                    "Type-2",
                    connector,
                    (v) => setState(() => connector = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _section("POWER OUTPUT"),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: power,
              dropdownColor: panel,
              decoration: _inputDecoration("Power"),
              items: const [
                DropdownMenuItem(value: "22", child: Text("22 kW")),
                DropdownMenuItem(value: "60", child: Text("60 kW")),
                DropdownMenuItem(value: "120", child: Text("120 kW")),
                DropdownMenuItem(value: "180", child: Text("180 kW")),
              ],
              onChanged: (v) => setState(() => power = v!),
            ),

            const SizedBox(height: 24),

            _section("PRICING"),

            const SizedBox(height: 10),

            _field(
              controller: priceController,
              label: "Price per kWh",
              hint: "18",
              icon: Icons.currency_rupee,
              number: true,
            ),

            const SizedBox(height: 24),

            _section("STATUS"),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.power_settings_new, color: cyan),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Available for booking",
                      style: TextStyle(color: text),
                    ),
                  ),
                  Switch(
                    value: available,
                    activeColor: lime,
                    onChanged: (v) => setState(() => available = v),
                  )
                ],
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  final name = nameController.text.trim();
                  final address = addressController.text.trim();
                  final priceText = priceController.text.trim();

                  if (name.isEmpty || priceText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please fill station name and price per kWh."),
                      ),
                    );
                    return;
                  }

                  final double price = double.tryParse(priceText) ?? 18.0;
                  final int powerKw = int.tryParse(power) ?? 60;

                  final chargerData = {
                    "name": name,
                    "power": powerKw,
                    "price": price,
                    "status": available ? "active" : "paused",
                    "reliability": 98,
                    "parking": address.isEmpty ? "Main Bay" : address,
                    "amenities": ["WiFi", "Parking", connector],
                  };

                  Navigator.pop(context, chargerData);
                },
                child: const Text(
                  "SAVE CHARGER",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: muted,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType:
          number ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: text),
      decoration: _inputDecoration(label).copyWith(
        hintText: hint,
        prefixIcon: Icon(icon, color: cyan),
      ),
    );
  }

  Widget _choice(
    String value,
    String group,
    Function(String) onTap,
  ) {
    final active = value == group;

    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? cyan.withOpacity(.15) : panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? cyan : Colors.white10,
          ),
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              color: active ? cyan : text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: muted),
      hintStyle: const TextStyle(color: muted),
      filled: true,
      fillColor: panel,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: cyan),
      ),
    );
  }
}