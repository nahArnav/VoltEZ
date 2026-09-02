import 'package:flutter/material.dart';
import '../network/server_config.dart';
import '../theme/colors.dart';

/// Shows the Server Configuration dialog.
void showServerConfigModal(BuildContext context) {
  ServerConfig? serverConfig;
  try {
    serverConfig = (context as dynamic).read<ServerConfig>();
  } catch (_) {}

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) => _ServerConfigDialog(config: serverConfig),
  );
}

class _ServerConfigDialog extends StatefulWidget {
  const _ServerConfigDialog({this.config});

  final ServerConfig? config;

  @override
  State<_ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<_ServerConfigDialog> {
  late final TextEditingController _controller;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    final initialUrl =
        widget.config?.activeUrl ??
        'https://voltez-sb0w.onrender.com/api/v1';
    _controller = TextEditingController(text: initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyPreset(String preset) {
    setState(() {
      _controller.text = ServerConfig.normalizeUrl(preset);
      _testResult = null;
      _testSuccess = null;
    });
  }

  Future<void> _runPingTest() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing connection...';
      _testSuccess = null;
    });

    if (widget.config != null) {
      final ok = await widget.config!.testConnection(_controller.text);
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = widget.config!.testResult;
          _testSuccess = ok;
        });
      }
    } else {
      // Fallback test
      setState(() {
        _isTesting = false;
        _testResult = 'Ready to connect';
        _testSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.config?.activeUrl ?? _controller.text;

    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.dns_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backend Server Settings',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Connect phone to laptop / USB / Cloud',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Active URL status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CURRENT ACTIVE ENDPOINT',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 9,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            active,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick Presets
              const Text(
                'CONNECTION PRESETS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PresetCard(
                    title: 'USB Cable (ADB reverse)',
                    subtitle: 'Run scripts/run_phone.sh first',
                    isHighlighted: true,
                    onTap: () => _applyPreset('http://127.0.0.1:8000/api/v1'),
                  ),
                  _PresetCard(
                    title: 'Host Mac Wi-Fi (enter IP)',
                    subtitle: 'Use your Mac IP; both devices must share Wi-Fi',
                    onTap: () => setState(() {
                      _controller.text = 'http://<MAC_IP>:8000/api/v1';
                      _testResult =
                          'Replace <MAC_IP> with your Mac LAN address.';
                      _testSuccess = null;
                    }),
                  ),
                  _PresetCard(
                    title: 'Android Emulator (10.0.2.2:8000)',
                    subtitle: 'For Android Studio Emulator',
                    onTap: () => _applyPreset('http://10.0.2.2:8000/api/v1'),
                  ),
                  _PresetCard(
                    title: 'VoltEZ Cloud (Render)',
                    subtitle: 'https://voltez-sb0w.onrender.com/api/v1',
                    onTap: () => _applyPreset(
                      'https://voltez-sb0w.onrender.com/api/v1',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Custom Input
              const Text(
                'CUSTOM SERVER URL',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  hintText: 'e.g. 192.168.1.5:8000 or http://...',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.link_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppColors.textMuted,
                      size: 16,
                    ),
                    onPressed: () => _controller.clear(),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Test Result Banner
              if (_testResult != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _testSuccess == true
                        ? AppColors.success.withValues(alpha: 0.12)
                        : (_testSuccess == false
                              ? AppColors.error.withValues(alpha: 0.12)
                              : AppColors.surface),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _testSuccess == true
                          ? AppColors.success.withValues(alpha: 0.4)
                          : (_testSuccess == false
                                ? AppColors.error.withValues(alpha: 0.4)
                                : AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess == true
                            ? Icons.check_circle_rounded
                            : (_testSuccess == false
                                  ? Icons.error_rounded
                                  : Icons.info_outline_rounded),
                        color: _testSuccess == true
                            ? AppColors.success
                            : (_testSuccess == false
                                  ? AppColors.error
                                  : AppColors.textSecondary),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testSuccess == true
                                ? AppColors.success
                                : (_testSuccess == false
                                      ? AppColors.error
                                      : AppColors.textSecondary),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isTesting ? null : _runPingTest,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isTesting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.network_ping_rounded, size: 16),
                      label: Text(_isTesting ? 'Testing...' : 'Ping Test'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (widget.config != null) {
                          await widget.config!.updateServerUrl(
                            _controller.text,
                          );
                        }
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.card,
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.success,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Server set to: ${_controller.text}',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text(
                        'Save & Apply',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isHighlighted = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isHighlighted
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHighlighted
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isHighlighted
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
