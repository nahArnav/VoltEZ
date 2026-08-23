import 'package:flutter/material.dart';
import '../earnings/earnings_screen.dart';
import '../auth/login_screen.dart';

const _bg = Color(0xFF05090E);
const _panel = Color(0xFF0B141C);
const _cyan = Color(0xFF50F5FF);
const _lime = Color(0xFFC9FF58);
const _violet = Color(0xFF9678FF);
const _text = Color(0xFFF1F7FA);
const _muted = Color(0xFF7D909D);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Sachi Pate';
  String _email = 'sachi.pate@email.com';
  String _phone = '+91 98765 43210';
  String _businessName = 'ABC Motors EV Station';
  String _location = 'Shivajinagar, Pune';

  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _darkModeEnabled = true;

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withOpacity(.045),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildProfileCard(),
              const SizedBox(height: 18),
              _buildStationCard(),
              const SizedBox(height: 22),
              _buildSectionTitle('STATION OVERVIEW'),
              const SizedBox(height: 12),
              _buildStats(),
              const SizedBox(height: 24),
              _buildSectionTitle('ACCOUNT & EARNINGS'),
              const SizedBox(height: 12),
              _buildAccountOptions(context),
              const SizedBox(height: 24),
              _buildSectionTitle('PREFERENCES'),
              const SizedBox(height: 12),
              _buildPreferences(),
              const SizedBox(height: 26),
              _buildLogoutButton(context),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'VOLTEZ • BUSINESS INTELLIGENCE',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _cyan.withOpacity(.18),
            ),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: _cyan,
            size: 23,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BUSINESS PROFILE',
                style: TextStyle(
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Station Owner Identity',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: _lime.withOpacity(.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _lime.withOpacity(.22),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.circle,
                color: _lime,
                size: 7,
              ),
              SizedBox(width: 6),
              Text(
                'VERIFIED HOST',
                style: TextStyle(
                  color: _lime,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final initials = _name.isNotEmpty
        ? _name.trim().split(' ').map((e) => e[0]).take(2).join()
        : 'SP';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _cyan.withOpacity(.14),
        ),
        boxShadow: [
          BoxShadow(
            color: _cyan.withOpacity(.035),
            blurRadius: 30,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _cyan.withOpacity(.35),
                  _violet.withOpacity(.35),
                ],
              ),
              border: Border.all(
                color: _cyan.withOpacity(.45),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _businessName,
                  style: const TextStyle(
                    color: _lime,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _email,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showEditProfileDialog,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _cyan.withOpacity(.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cyan.withOpacity(.3)),
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: _cyan,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _violet.withOpacity(.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _violet.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.ev_station_rounded,
                  color: _violet,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PRIMARY CHARGING LOCATION',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _businessName,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: Colors.white.withOpacity(.05),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stationSpec('LOCATION', _location),
              _verticalDivider(),
              _stationSpec('ACTIVE CHARGERS', '3 Active'),
              _verticalDivider(),
              _stationSpec('TOTAL POWER', '180 kW'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stationSpec(String title, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _muted,
              fontSize: 7,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _text,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withOpacity(.06),
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: _cyan,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: _text,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _activityStat(
            Icons.currency_rupee_rounded,
            '₹1,28,640',
            'TOTAL REVENUE',
            _lime,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _activityStat(
            Icons.bolt_rounded,
            '1,247',
            'kWh DISPENSED',
            _cyan,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _activityStat(
            Icons.check_circle_outline_rounded,
            '98%',
            'RELIABILITY',
            _violet,
          ),
        ),
      ],
    );
  }

  Widget _activityStat(
    IconData icon,
    String value,
    String title,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white.withOpacity(.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: _muted,
              fontSize: 7,
              fontWeight: FontWeight.bold,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountOptions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(.05),
        ),
      ),
      child: Column(
        children: [
          _accountTile(
            icon: Icons.person_outline_rounded,
            title: 'Account Information',
            subtitle: 'Name, email, phone and business details',
            color: _cyan,
            onTap: _showAccountInfoSheet,
          ),
          _divider(),
          _accountTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Earnings & Revenue',
            subtitle: 'Track total revenue & session earnings',
            color: _lime,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EarningsScreen(),
                ),
              );
            },
          ),
          _divider(),
          _accountTile(
            icon: Icons.payments_outlined,
            title: 'Money Earned & Payouts',
            subtitle: 'Bank account settlements & pending payouts',
            color: _violet,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EarningsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _accountTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(.07),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: color,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: _muted,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferences() {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(.05),
        ),
      ),
      child: Column(
        children: [
          _preferenceTile(
            Icons.notifications_none_rounded,
            'Notifications',
            'Booking alerts and revenue updates',
            _notificationsEnabled,
            (val) {
              setState(() => _notificationsEnabled = val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(val ? 'Notifications enabled' : 'Notifications disabled'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          _divider(),
          _preferenceTile(
            Icons.location_on_outlined,
            'Location Access',
            'Geocoding station coordinates',
            _locationEnabled,
            (val) {
              setState(() => _locationEnabled = val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(val ? 'Location access enabled' : 'Location access disabled'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          _divider(),
          _preferenceTile(
            Icons.dark_mode_outlined,
            'Dark Interface',
            'Command centre dark HUD theme',
            _darkModeEnabled,
            (val) {
              setState(() => _darkModeEnabled = val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(val ? 'Dark mode enabled' : 'Light mode enabled'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _preferenceTile(
    IconData icon,
    String title,
    String subtitle,
    bool enabled,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 11,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: _muted,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: _cyan,
            activeTrackColor: _cyan.withOpacity(.18),
            inactiveThumbColor: _muted,
            inactiveTrackColor: Colors.white.withOpacity(.05),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () {
          _showLogoutDialog(context);
        },
        icon: const Icon(
          Icons.logout_rounded,
          size: 18,
        ),
        label: const Text(
          'SIGN OUT',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: BorderSide(
            color: Colors.redAccent.withOpacity(.25),
          ),
          backgroundColor: Colors.redAccent.withOpacity(.035),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _showAccountInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined, color: _cyan, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    "Account Information",
                    style: TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _infoTile("Owner Name", _name),
              _infoTile("Email Address", _email),
              _infoTile("Phone Number", _phone),
              _infoTile("Business Name", _businessName),
              _infoTile("Station Location", _location),
              _infoTile("Host Status", "Verified Commercial Partner"),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cyan,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditProfileDialog();
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text("EDIT ACCOUNT DETAILS"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
          Text(value, style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);
    final businessCtrl = TextEditingController(text: _businessName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Edit Business Profile",
            style: TextStyle(color: _text, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _editField(nameCtrl, "Owner Name", Icons.person_outline),
                const SizedBox(height: 12),
                _editField(emailCtrl, "Email", Icons.email_outlined),
                const SizedBox(height: 12),
                _editField(phoneCtrl, "Phone Number", Icons.phone_outlined),
                const SizedBox(height: 12),
                _editField(businessCtrl, "Business Name", Icons.business_outlined),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: _muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _lime,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                setState(() {
                  _name = nameCtrl.text.trim();
                  _email = emailCtrl.text.trim();
                  _phone = phoneCtrl.text.trim();
                  _businessName = businessCtrl.text.trim();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Profile updated successfully!"),
                  ),
                );
              },
              child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _editField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: _text, fontSize: 13),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _cyan, size: 18),
        hintText: hint,
        hintStyle: const TextStyle(color: _muted),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Sign out?',
            style: TextStyle(
              color: _text,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'You will need to sign in again to access your Voltez business account.',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              child: const Text(
                'SIGN OUT',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}