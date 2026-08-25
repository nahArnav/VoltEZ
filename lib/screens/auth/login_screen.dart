import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../../widgets/holographic_ev.dart';
import '../shell/main_screen_screen.dart';

enum AccountRole { user, business }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AccountRole? _role;
  bool _signUp = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: holoBg,
        body: SafeArea(
          child: _role == null
              ? _RoleSelect(onSelect: (r) => setState(() => _role = r))
              : _AuthPanel(
                  role: _role!,
                  signUp: _signUp,
                  onBack: () => setState(() => _role = null),
                  onMode: (v) => setState(() => _signUp = v),
                ),
        ),
      );
}

class _RoleSelect extends StatelessWidget {
  const _RoleSelect({required this.onSelect});
  final ValueChanged<AccountRole> onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, box) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'VOLTEZ',
                  style: TextStyle(
                    color: holoCyan,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const Text('INTELLIGENT EV CHARGING NETWORK', style: _micro),
                const SizedBox(height: 12),
                const HolographicEv(progress: .62, compact: true),
                const SizedBox(height: 18),
                const Text(
                  'Choose your access',
                  style: TextStyle(
                    color: holoText,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A private, connected energy experience.',
                  style: TextStyle(color: holoMuted),
                ),
                const SizedBox(height: 22),
                _AccessCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Driver access',
                  detail: 'Find and use intelligent charging.',
                  color: holoCyan,
                  onTap: () => onSelect(AccountRole.user),
                ),
                const SizedBox(height: 12),
                _AccessCard(
                  icon: Icons.business_center_outlined,
                  title: 'Business owner',
                  detail: 'Manage chargers, fleet and insights.',
                  color: holoEmerald,
                  onTap: () => onSelect(AccountRole.business),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title, detail;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: holoSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: .38)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: holoText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: const TextStyle(color: holoMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: color),
            ],
          ),
        ),
      );
}

class _AuthPanel extends StatefulWidget {
  const _AuthPanel({
    required this.role,
    required this.signUp,
    required this.onBack,
    required this.onMode,
  });

  final AccountRole role;
  final bool signUp;
  final VoidCallback onBack;
  final ValueChanged<bool> onMode;

  @override
  State<_AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends State<_AuthPanel> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _remember = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
  if (!(_form.currentState?.validate() ?? false)) return;

  if (widget.role == AccountRole.business) {
    Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (_) => const MainShellScreen()),
  (route) => false,
);
  } else {
    // TODO: Navigate to driver dashboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Driver dashboard coming soon'),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final accent = widget.role == AccountRole.business ? holoEmerald : holoCyan;

    return LayoutBuilder(
      builder: (_, box) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: holoText),
              ),
              const SizedBox(height: 4),
              const Center(
                child: SizedBox(
                  width: 260,
                  child: HolographicEv(progress: .78, compact: true),
                ),
              ),
              Text(
                widget.signUp ? 'Create your account' : 'Welcome back',
                style: const TextStyle(
                  color: holoText,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                "Access India's intelligent EV charging network",
                style: TextStyle(color: holoMuted),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _mode(false, accent)),
                  const SizedBox(width: 8),
                  Expanded(child: _mode(true, accent)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: holoSurface.withValues(alpha: .86),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: .32)),
                ),
                child: Form(
                  key: _form,
                  child: Column(
                    children: [
                      if (widget.signUp) ...[
                        _field(_name, 'Full name', Icons.person_outline),
                        const SizedBox(height: 12),
                      ],
                      _field(
                        _email,
                        'Email address',
                        Icons.alternate_email,
                        email: true,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        _password,
                        'Password',
                        Icons.lock_outline,
                        secret: !_show,
                        trail: IconButton(
                          onPressed: () => setState(() => _show = !_show),
                          icon: Icon(
                            _show ? Icons.visibility_off : Icons.visibility,
                            color: holoMuted,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _remember,
                            onChanged: (v) =>
                                setState(() => _remember = v ?? false),
                            activeColor: accent,
                          ),
                          const Text(
                            'Remember me',
                            style: TextStyle(color: holoMuted, fontSize: 12),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(color: holoCyan, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: holoBg,
                          ),
                          child: Text(
                            widget.signUp ? 'CREATE ACCOUNT' : 'CONTINUE',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mode(bool signup, Color accent) => OutlinedButton(
        onPressed: () => widget.onMode(signup),
        style: OutlinedButton.styleFrom(
          backgroundColor: widget.signUp == signup
              ? accent.withValues(alpha: .13)
              : Colors.transparent,
          foregroundColor: widget.signUp == signup ? accent : holoMuted,
          side: BorderSide(
            color: widget.signUp == signup
                ? accent
                : holoMuted.withValues(alpha: .35),
          ),
        ),
        child: Text(signup ? 'SIGN UP' : 'LOG IN'),
      );

  Widget _field(
    TextEditingController c,
    String text,
    IconData icon, {
    bool email = false,
    bool secret = false,
    Widget? trail,
  }) =>
      TextFormField(
        controller: c,
        obscureText: secret,
        keyboardType: email ? TextInputType.emailAddress : null,
        style: const TextStyle(color: holoText),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: holoCyan),
          suffixIcon: trail,
          hintText: text,
          hintStyle: const TextStyle(color: holoMuted),
          filled: true,
          fillColor: holoBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: holoCyan.withValues(alpha: .25)),
          ),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return '$text is required';
          }
          if (email) {
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(v.trim())) {
              return 'Please enter a valid email address';
            }
          } else if (secret) {
            if (v.trim().length < 6) {
              return 'Password must be at least 6 characters';
            }
          }
          return null;
        },
      );
}

const _micro = TextStyle(
  color: holoMuted,
  fontSize: 10,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.2,
);