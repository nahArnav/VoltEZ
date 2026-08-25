import 'package:flutter/material.dart';

const Color _bg = Color(0xFF05090E);
const Color _panel = Color(0xFF0B141C);
const Color _cyan = Color(0xFF50F5FF);
const Color _lime = Color(0xFFC9FF58);
const Color _text = Color(0xFFF1F8FF);
const Color _muted = Color(0xFF7990A1);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  int _currentStep = 0; // 0: Enter Email, 1: Enter OTP & New Password
  bool _isLoading = false;
  final _newPasswordController = TextEditingController();

  void _sendOtp() {
    if (_emailController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });
    });
  }

  void _resetPassword() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _panel,
          content: Text("Password updated successfully! Please sign in.", style: TextStyle(color: _lime)),
        ),
      );
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              if (_currentStep == 0) _buildEmailStep() else _buildOtpAndResetStep(),
            ],
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
          ),
          child: const Text(
            "RECOVERY PORTAL",
            style: TextStyle(color: _cyan, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _currentStep == 0 ? "Reset Access Key" : "Verify Authorization",
          style: const TextStyle(color: _text, fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          _currentStep == 0
              ? "Enter your registered host email to receive a secure authorization OTP."
              : "Enter the 4-digit code sent to ${_emailController.text}.",
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildEmailStep() {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          style: const TextStyle(color: _text, fontSize: 13),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.alternate_email_rounded, color: _cyan, size: 18),
            hintText: "host@voltez.com",
            hintStyle: const TextStyle(color: _muted, fontSize: 12),
            filled: true,
            fillColor: _panel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _sendOtp,
            child: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text("TRANSMIT OTP", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpAndResetStep() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            return SizedBox(
              width: 60,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(color: _cyan, fontSize: 22, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: _panel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _cyan.withOpacity(0.3)),
                  ),
                ),
                onChanged: (v) {
                  if (v.isNotEmpty && index < 3) {
                    _focusNodes[index + 1].requestFocus();
                  } else if (v.isEmpty && index > 0) {
                    _focusNodes[index - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          style: const TextStyle(color: _text, fontSize: 13),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_reset_rounded, color: _lime, size: 18),
            hintText: "Enter New Master Password",
            hintStyle: const TextStyle(color: _muted, fontSize: 12),
            filled: true,
            fillColor: _panel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _lime,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _resetPassword,
            child: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text("UPDATE ACCESS KEY", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }
}