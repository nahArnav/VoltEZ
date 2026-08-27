import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/components/holographic_ev.dart';
import '../../shared/models/models.dart';

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
        backgroundColor: AppColors.background,
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
        builder: (_, box) {
          final heroWidth = math.min(math.max(0.0, box.maxWidth - 48), 360.0);
          return SingleChildScrollView(
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
                      color: AppColors.primary,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const Text(
                    'INTELLIGENT EV CHARGING NETWORK',
                    style: _micro,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: SizedBox(
                      width: heroWidth,
                      child: const HolographicEv(progress: .62, compact: true),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Choose your access', style: AppTypography.displaySmall),
                  const SizedBox(height: 8),
                  const Text(
                    'A private, connected energy experience.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 22),
                  _AccessCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Driver access',
                    detail: 'Find and use intelligent charging.',
                    color: AppColors.primary,
                    onTap: () => onSelect(AccountRole.driver),
                  ),
                  const SizedBox(height: 12),
                  _AccessCard(
                    icon: Icons.business_center_outlined,
                    title: 'Business owner',
                    detail: 'Manage chargers, fleet and insights.',
                    color: AppColors.success,
                    onTap: () => onSelect(AccountRole.owner),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
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
  Widget build(BuildContext c) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
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
                    Text(title, style: AppTypography.headlineSmall),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: AppTypography.bodySmall,
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

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final success = widget.signUp
        ? await auth.signup(
            _name.text.trim(),
            _email.text.trim(),
            _password.text,
            role: widget.role,
          )
        : await auth.login(_email.text.trim(), _password.text);

    if (!mounted || !success) return;

    if (auth.currentRole != widget.role) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This account belongs to a different role.')),
      );
      await auth.logout();
      return;
    }

    if (widget.role == AccountRole.owner) {
      context.go('/business/dashboard');
    } else {
      context.go('/driver/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final accent =
        widget.role == AccountRole.owner ? AppColors.success : AppColors.primary;

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
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary),
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
                style: AppTypography.displayMedium,
              ),
              const SizedBox(height: 7),
              const Text(
                "Access India's intelligent EV charging network",
                style: TextStyle(color: AppColors.textSecondary),
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
                  color: AppColors.card.withValues(alpha: .86),
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
                            color: AppColors.textMuted,
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
                          Text(
                            'Remember me',
                            style: AppTypography.bodySmall,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      PrimaryButton(
                        text: widget.signUp ? 'CREATE ACCOUNT' : 'CONTINUE',
                        onPressed: _submit,
                        isLoading: auth.isLoading,
                        isExpanded: true,
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          auth.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 11),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.g_mobiledata_rounded),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: .4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Turnstile verification runs securely before continuing.',
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: .7),
                    fontSize: 10,
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
              ? accent.withValues(alpha: 0.13)
              : Colors.transparent,
          foregroundColor: widget.signUp == signup ? accent : AppColors.textMuted,
          side: BorderSide(
            color: widget.signUp == signup
                ? accent
                : AppColors.textMuted.withValues(alpha: 0.35),
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
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primary),
          suffixIcon: trail,
          hintText: text,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: .25),
            ),
          ),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      );
}

const _micro = TextStyle(
  color: AppColors.textMuted,
  fontSize: 10,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.2,
);
