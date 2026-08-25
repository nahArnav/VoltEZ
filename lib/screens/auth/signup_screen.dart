import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'station_onboarding_wizard_screen.dart';

const Color _bg = Color(0xFF05090E);
const Color _panel = Color(0xFF0B141C);
const Color _cyan = Color(0xFF50F5FF);
const Color _lime = Color(0xFFC9FF58);
const Color _text = Color(0xFFF1F8FF);
const Color _muted = Color(0xFF7990A1);
const Color _danger = Color(0xFFFF5F6D);

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  void _handleSignup() {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _panel,
          content: Text('Please accept the Host Terms of Service', style: TextStyle(color: _danger)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // Navigate directly into the Station Setup Wizard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StationOnboardingWizardScreen(
            hostName: _nameController.text.trim(),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _buildHeader(),
                const SizedBox(height: 28),
                _buildTextField(
                  controller: _nameController,
                  label: "FULL NAME",
                  hint: "Sachi Pate",
                  icon: Icons.person_outline_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: "BUSINESS EMAIL",
                  hint: "host@voltez.com",
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  label: "PHONE NUMBER",
                  hint: "+91 98765 43210",
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Enter valid 10-digit number' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordController,
                  label: "PASSWORD",
                  hint: "••••••••••••",
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                  validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 20),
                _buildTermsCheckbox(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
                const SizedBox(height: 24),
                _buildLoginPrompt(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _cyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _cyan.withOpacity(0.25)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, color: _cyan, size: 14),
              SizedBox(width: 4),
              Text(
                "HOST REGISTRATION",
                style: TextStyle(color: _cyan, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Join Voltez Network",
          style: TextStyle(color: _text, fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          "Monetize and manage your EV charging infrastructure with smart AI telemetry.",
          style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: _text, fontSize: 13),
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _cyan, size: 18),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: _muted, size: 18),
                    onPressed: onToggleObscure,
                  )
                : null,
            hintText: hint,
            hintStyle: const TextStyle(color: _muted, fontSize: 12),
            filled: true,
            fillColor: _panel,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _cyan, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _agreedToTerms,
          activeColor: _cyan,
          checkColor: Colors.black,
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
          onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
        ),
        const Expanded(
          child: Text(
            "I agree to the Commercial Host Terms of Service & Privacy Policy.",
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lime,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: _isLoading ? null : _handleSignup,
        child: _isLoading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Text(
                "CREATE HOST ACCOUNT",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1),
              ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Already have a station account? ", style: TextStyle(color: _muted, fontSize: 12)),
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text(
              "Sign In",
              style: TextStyle(color: _cyan, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}