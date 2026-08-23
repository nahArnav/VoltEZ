import 'package:flutter/material.dart';

const _bg = Color(0xFF05090E);
const _panel = Color(0xFF0B141C);
const _cyan = Color(0xFF50F5FF);
const _lime = Color(0xFFC9FF58);
const _violet = Color(0xFF9678FF);
const _text = Color(0xFFF1F7FA);
const _muted = Color(0xFF7D909D);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget _divider() {
  return Divider(
    height: 1,
    thickness: 1,
    color: Colors.white.withOpacity(.045),
  );
}
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
              _buildVehicleCard(),
              const SizedBox(height: 22),
              _buildSectionTitle('YOUR ACTIVITY'),
              const SizedBox(height: 12),
              _buildStats(),
              const SizedBox(height: 24),
              _buildSectionTitle('ACCOUNT'),
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
                  'VOLTEZ • ELECTRIC MOBILITY',
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
                'PROFILE',
                style: TextStyle(
                  color: _text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Your Voltez identity',
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
                'ACTIVE',
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
            width: 70,
            height: 70,
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
            child: const Center(
              child: Text(
                'SP',
                style: TextStyle(
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sachi Pate',
                  style: TextStyle(
                    color: _text,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'sachi.pate@email.com',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: _cyan,
                      size: 13,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Verified account',
                      style: TextStyle(
                        color: _cyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.035),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.edit_outlined,
              color: _muted,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard() {
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
                  Icons.electric_car_outlined,
                  color: _violet,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRIMARY VEHICLE',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tata Nexon EV',
                      style: TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _muted,
                size: 13,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white.withOpacity(.05),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _vehicleSpec('BATTERY', '40.5 kWh'),
              _verticalDivider(),
              _vehicleSpec('RANGE', '465 km'),
              _verticalDivider(),
              _vehicleSpec('PORT', 'CCS2'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehicleSpec(String title, String value) {
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
            style: const TextStyle(
              color: _text,
              fontSize: 11,
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
            Icons.bolt_rounded,
            '1,247',
            'kWh USED',
            _cyan,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _activityStat(
            Icons.ev_station_rounded,
            '38',
            'SESSIONS',
            _violet,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _activityStat(
            Icons.eco_outlined,
            '286',
            'KG CO₂',
            _lime,
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
        horizontal: 12,
        vertical: 15,
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
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: _text,
              fontSize: 17,
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
              letterSpacing: .8,
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
            title: 'Personal information',
            subtitle: 'Name, email and phone',
            color: _cyan,
          ),
          _divider(),
          _accountTile(
            icon: Icons.directions_car_outlined,
            title: 'My vehicles',
            subtitle: 'Manage your EVs',
            color: _violet,
          ),
          _divider(),
          _accountTile(
            icon: Icons.credit_card_outlined,
            title: 'Payment methods',
            subtitle: 'Cards and payment preferences',
            color: _lime,
          ),
          _divider(),
          _accountTile(
            icon: Icons.receipt_long_outlined,
            title: 'Transaction history',
            subtitle: 'View all payments',
            color: _cyan,
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
  }) {
    return InkWell(
      onTap: () {},
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
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            'Charging and booking alerts',
            true,
          ),
          _divider(),
          _preferenceTile(
            Icons.location_on_outlined,
            'Location access',
            'Find nearby charging stations',
            true,
          ),
          _divider(),
          _preferenceTile(
            Icons.dark_mode_outlined,
            'Dark interface',
            'HUD optimized appearance',
            true,
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
            onChanged: (_) {},
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
          backgroundColor:
              Colors.redAccent.withOpacity(.035),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
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
            'You will need to sign in again to access your Voltez account.',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
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
                Navigator.pop(context);
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