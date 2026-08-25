import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../shared/components/holographic_ev.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2850), () {
      if (mounted) context.go('/login');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _HudGrid()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    final p = _c.value;
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'VOLTEZ // VEHICLE OS',
                              style: _micro,
                            ),
                            Text(
                              'BOOT ${(p * 100).round().toString().padLeft(3, '0')}%',
                              style: _micro.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Transform.scale(
                          scale: 1 + .06 * p,
                          child: HolographicEv(progress: p),
                        ),
                        const Spacer(),
                        Opacity(
                          opacity: Curves.easeIn.transform((p / .55).clamp(0, 1)),
                          child: Column(
                            children: [
                              const Text(
                                'VOLTEZ',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Powering the Future of EV Charging',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  letterSpacing: .5,
                                ),
                              ),
                              const SizedBox(height: 22),
                              LinearProgressIndicator(
                                value: p,
                                color: AppColors.primary,
                                backgroundColor: AppColors.surface,
                                minHeight: 3,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
}

const _micro = TextStyle(
  color: AppColors.textMuted,
  fontSize: 10,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.35,
);

class _HudGrid extends CustomPainter {
  const _HudGrid();

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = AppColors.primary.withValues(alpha: .055)
      ..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 32) {
      c.drawLine(Offset(x, 0), Offset(x, s.height), p);
    }
    for (double y = 0; y < s.height; y += 32) {
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _HudGrid o) => false;
}
