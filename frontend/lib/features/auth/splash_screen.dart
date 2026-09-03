import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// VoltEZ Splash Screen — Realistic EV Animation
/// Features a procedurally-drawn electric car with:
/// - Smooth body with reflections
/// - Animated wheels with spokes
/// - Pulsing charging indicator on dashboard
/// - Battery level fill animation
/// - Charging cable with energy particles
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Entrance animation
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  // Wheel spin
  late final AnimationController _wheelController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat();

  // Battery fill
  late final AnimationController _batteryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  // Charge pulse
  late final AnimationController _chargeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  // Progress
  late final AnimationController _progressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  Timer? _navTimer;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _entranceController.forward();
    _batteryController.forward();
    _progressController.forward();
    _navTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted && !_navigating) {
        _navigating = true;
        // Stop all animations before navigation to prevent mouse_tracker assertion
        _wheelController.stop();
        _chargeController.stop();
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _entranceController.dispose();
    _wheelController.dispose();
    _batteryController.dispose();
    _chargeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle background
          const _SoftBackground(),

          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _entranceController,
                _batteryController,
                _chargeController,
                _progressController,
              ]),
              builder: (_, _) {
                final entrance = _entranceController.value;
                final battery = _batteryController.value;
                final charge = _chargeController.value;
                final progress = _progressController.value;

                return Column(
                  children: [
                    const SizedBox(height: 50),

                    // ─── Top bar ───
                    Opacity(
                      opacity: Curves.easeIn.transform((entrance * 4).clamp(0, 1)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'VOLTEZ // VEHICLE OS',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textMuted,
                                letterSpacing: 0.12,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'v1.0',
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // ─── Realistic EV ───
                    Transform.translate(
                      offset: Offset(0, 30 * (1 - entrance)),
                      child: Opacity(
                        opacity: Curves.easeOut.transform(
                            ((entrance - 0.1) * 2).clamp(0, 1)),
                        child: SizedBox(
                          width: 320,
                          height: 180,
                          child: CustomPaint(
                            painter: RealisticEVPainter(
                              wheelRotation: _wheelController.value * 2 * math.pi,
                              batteryLevel: Curves.easeOut.transform(
                                  (battery * 1.2).clamp(0, 1)),
                              chargeIntensity: charge,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─── Brand ───
                    Opacity(
                      opacity: Curves.easeOut.transform(
                          ((entrance - 0.3) * 3).clamp(0, 1)),
                      child: Transform.translate(
                        offset: Offset(0, 15 * (1 - entrance)),
                        child: const Text(
                                       'VOLTEZ',
                                        style: TextStyle(
                                        color: Color(0xFF176B4D),
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.5,
                                        ),
                                       ),
                                     ),
                                    ),

                    const SizedBox(height: 10),

                    Opacity(
                      opacity: Curves.easeOut.transform(
                          ((entrance - 0.4) * 3).clamp(0, 1)),
                      child: Text(
                        'Powering the Future of EV Charging',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // ─── Feature pills ───
                    Opacity(
                      opacity: Curves.easeOut.transform(
                          ((entrance - 0.5) * 3).clamp(0, 1)),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(Icons.bolt_rounded, 'Smart Charging', AppColors.primary),
                          _Pill(Icons.route_rounded, 'Route Planning', AppColors.secondary),
                          _Pill(Icons.schedule_rounded, 'Reservations', AppColors.marigold),
                        ],
                      ),
                    ),


                    const Spacer(flex: 2),

                    // ─── Progress ───
                    Opacity(
                      opacity: Curves.easeIn.transform(
                          ((entrance - 0.5) * 3).clamp(0, 1)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 3,
                                color: AppColors.primary,
                                backgroundColor: AppColors.surfaceContainer,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Initializing... ${(progress * 100).round()}%',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textMuted,
                                letterSpacing: 0.08,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 50),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feature pill ───
class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.labelMedium.copyWith(
            color: color, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0,
          )),
        ],
      ),
    );
  }
}

// ─── Soft background ───
class _SoftBackground extends StatelessWidget {
  const _SoftBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background,
            AppColors.surface,
            AppColors.background,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REALISTIC EV PAINTER
// Draws a side-view electric car with detailed body, windows, wheels,
// charging indicator, and battery visualization.
// ═══════════════════════════════════════════════════════════════════════════════

class RealisticEVPainter extends CustomPainter {
  RealisticEVPainter({
    required this.wheelRotation,
    required this.batteryLevel,
    required this.chargeIntensity,
  });

  final double wheelRotation;
  final double batteryLevel;
  final double chargeIntensity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;

    // ─── Ground shadow ───
    final shadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - 120, h * 0.82),
        Offset(centerX + 120, h * 0.82),
        [
          Colors.black.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.08),
          Colors.black.withValues(alpha: 0.0),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, h * 0.82),
        width: 240,
        height: 16,
      ),
      shadowPaint,
    );

    // ─── Car body path ───
    final bodyPath = Path();
    // Lower body
    bodyPath.moveTo(centerX - 110, h * 0.62);
    bodyPath.lineTo(centerX - 115, h * 0.58);
    bodyPath.quadraticBezierTo(centerX - 118, h * 0.54, centerX - 112, h * 0.52);
    // Roof line
    bodyPath.lineTo(centerX - 60, h * 0.35);
    bodyPath.quadraticBezierTo(centerX - 50, h * 0.30, centerX - 30, h * 0.28);
    // Roof
    bodyPath.lineTo(centerX + 40, h * 0.28);
    bodyPath.quadraticBezierTo(centerX + 60, h * 0.28, centerX + 70, h * 0.32);
    // Rear windshield
    bodyPath.lineTo(centerX + 85, h * 0.45);
    bodyPath.quadraticBezierTo(centerX + 95, h * 0.50, centerX + 110, h * 0.52);
    // Rear
    bodyPath.lineTo(centerX + 115, h * 0.58);
    bodyPath.quadraticBezierTo(centerX + 118, h * 0.62, centerX + 115, h * 0.65);
    // Bottom
    bodyPath.lineTo(centerX + 80, h * 0.65);
    // Rear wheel arch
    bodyPath.quadraticBezierTo(centerX + 72, h * 0.72, centerX + 55, h * 0.74);
    bodyPath.quadraticBezierTo(centerX + 38, h * 0.76, centerX + 30, h * 0.74);
    bodyPath.lineTo(centerX - 30, h * 0.74);
    // Front wheel arch
    bodyPath.quadraticBezierTo(centerX - 38, h * 0.76, centerX - 55, h * 0.74);
    bodyPath.quadraticBezierTo(centerX - 72, h * 0.72, centerX - 80, h * 0.65);
    bodyPath.lineTo(centerX - 110, h * 0.62);
    bodyPath.close();

    // Body gradient fill
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, h * 0.28),
        Offset(0, h * 0.74),
        [
          const Color(0xFF2D6A4F), // Leaf Green top
          const Color(0xFF1D5E3F), // Darker green
          const Color(0xFF1A4E35), // Darkest green bottom
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawPath(bodyPath, bodyPaint);

    // Body highlight reflection
    final highlightPath = Path();
    highlightPath.moveTo(centerX - 100, h * 0.52);
    highlightPath.lineTo(centerX - 55, h * 0.36);
    highlightPath.lineTo(centerX + 35, h * 0.32);
    highlightPath.lineTo(centerX + 65, h * 0.35);
    highlightPath.lineTo(centerX + 90, h * 0.50);
    highlightPath.lineTo(centerX - 100, h * 0.52);
    highlightPath.close();

    final highlightPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, h * 0.30),
        Offset(0, h * 0.52),
        [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.03),
        ],
      );
    canvas.drawPath(highlightPath, highlightPaint);

    // ─── Windows ───
    final windowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, h * 0.30),
        Offset(0, h * 0.48),
        [
          const Color(0xFF1D3557).withValues(alpha: 0.7),
          const Color(0xFF1D3557).withValues(alpha: 0.4),
        ],
      );

    // Front window
    final frontWindow = Path();
    frontWindow.moveTo(centerX - 55, h * 0.36);
    frontWindow.lineTo(centerX - 25, h * 0.30);
    frontWindow.lineTo(centerX + 5, h * 0.30);
    frontWindow.lineTo(centerX + 5, h * 0.46);
    frontWindow.lineTo(centerX - 45, h * 0.46);
    frontWindow.close();
    canvas.drawPath(frontWindow, windowPaint);

    // Rear window
    final rearWindow = Path();
    rearWindow.moveTo(centerX + 10, h * 0.30);
    rearWindow.lineTo(centerX + 40, h * 0.30);
    rearWindow.lineTo(centerX + 68, h * 0.38);
    rearWindow.lineTo(centerX + 10, h * 0.46);
    rearWindow.close();
    canvas.drawPath(rearWindow, windowPaint);

    // Window divider
    final dividerPaint = Paint()
      ..color = const Color(0xFF1A4E35)
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(centerX + 7, h * 0.30),
      Offset(centerX + 7, h * 0.46),
      dividerPaint,
    );

    // Window reflection
    final reflectionPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(centerX - 40, h * 0.34),
      Offset(centerX - 10, h * 0.32),
      reflectionPaint,
    );
    canvas.drawLine(
      Offset(centerX + 20, h * 0.32),
      Offset(centerX + 50, h * 0.35),
      reflectionPaint,
    );

    // ─── Headlight ───
    final headlightPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - 115, h * 0.52),
        Offset(centerX - 105, h * 0.52),
        [
          const Color(0xFFBBD3FD), // Light blue
          const Color(0xFF7EB8F8),
        ],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 116, h * 0.52, 12, 8),
        const Radius.circular(3),
      ),
      headlightPaint,
    );

    // ─── Taillight ───
    final taillightPaint = Paint()..color = const Color(0xFFE76F51); // Coral
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX + 106, h * 0.52, 10, 8),
        const Radius.circular(3),
      ),
      taillightPaint,
    );

    // ─── Door line ───
    final doorPaint = Paint()
      ..color = const Color(0xFF1A4E35).withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(centerX - 10, h * 0.46),
      Offset(centerX - 15, h * 0.64),
      doorPaint,
    );

    // ─── Door handle ───
    final handlePaint = Paint()..color = Colors.white.withValues(alpha: 0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX + 15, h * 0.50, 18, 4),
        const Radius.circular(2),
      ),
      handlePaint,
    );

    // ─── Charging port (front fender) ───
    final portPaint = Paint()..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawCircle(Offset(centerX - 75, h * 0.54), 5, portPaint);
    if (chargeIntensity > 0.3) {
      final chargePaint = Paint()
        ..color = AppColors.primary.withValues(alpha: chargeIntensity * 0.6);
      canvas.drawCircle(Offset(centerX - 75, h * 0.54), 3, chargePaint);
    }

    // ─── Battery indicator (dashboard glow through window) ───
    final batteryPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - 35, h * 0.42),
        Offset(centerX + 30, h * 0.42),
        [
          AppColors.primary.withValues(alpha: 0.1),
          AppColors.primary.withValues(alpha: 0.05),
        ],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 35, h * 0.41, 65 * batteryLevel, 3),
        const Radius.circular(1.5),
      ),
      batteryPaint,
    );

    // ─── Wheels ───
    _drawWheel(canvas, Offset(centerX - 55, h * 0.74), 22);
    _drawWheel(canvas, Offset(centerX + 55, h * 0.74), 22);

    // ─── Wheel spokes (rotating) ───
    _drawSpokes(canvas, Offset(centerX - 55, h * 0.74), 16, wheelRotation);
    _drawSpokes(canvas, Offset(centerX + 55, h * 0.74), 16, wheelRotation);

    // ─── Charging bolt (above car) ───
    if (chargeIntensity > 0.2) {
      final boltOpacity = (chargeIntensity - 0.2) * 1.25;
      final boltPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: boltOpacity * 0.7);

      final boltPath = Path();
      boltPath.moveTo(centerX - 5, h * 0.15);
      boltPath.lineTo(centerX - 12, h * 0.22);
      boltPath.lineTo(centerX - 2, h * 0.22);
      boltPath.lineTo(centerX + 5, h * 0.15);
      boltPath.lineTo(centerX - 1, h * 0.22);
      boltPath.lineTo(centerX + 8, h * 0.22);
      boltPath.close();
      canvas.drawPath(boltPath, boltPaint);
    }

    // ─── Energy particles ───
    final particlePaint = Paint();
    for (int i = 0; i < 5; i++) {
      final t = (chargeIntensity + i * 0.2) % 1.0;
      final px = centerX - 75 - (t * 40);
      final py = h * 0.54 - (t * 20);
      particlePaint.color = AppColors.primary.withValues(alpha: (1 - t) * 0.5);
      canvas.drawCircle(Offset(px, py), 2 - (t * 1.5), particlePaint);
    }
  }

  void _drawWheel(Canvas canvas, Offset center, double radius) {
    // Tire
    final tirePaint = Paint()..color = const Color(0xFF2D3748);
    canvas.drawCircle(center, radius, tirePaint);

    // Tire rim highlight
    final rimHighlight = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          Colors.white.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(center, radius, rimHighlight);

    // Inner rim
    final rimPaint = Paint()..color = const Color(0xFF718096);
    canvas.drawCircle(center, radius * 0.65, rimPaint);

    // Center cap
    final capPaint = Paint()..color = const Color(0xFFA0AEC0);
    canvas.drawCircle(center, radius * 0.25, capPaint);

    // Center logo dot
    final dotPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(center, radius * 0.1, dotPaint);
  }

  void _drawSpokes(Canvas canvas, Offset center, double radius, double rotation) {
    final spokePaint = Paint()
      ..color = const Color(0xFFA0AEC0)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final angle = rotation + (i * math.pi * 2 / 5);
      final x1 = center.dx + math.cos(angle) * radius * 0.25;
      final y1 = center.dy + math.sin(angle) * radius * 0.25;
      final x2 = center.dx + math.cos(angle) * radius * 0.6;
      final y2 = center.dy + math.sin(angle) * radius * 0.6;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), spokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RealisticEVPainter old) =>
      old.wheelRotation != wheelRotation ||
      old.batteryLevel != batteryLevel ||
      old.chargeIntensity != chargeIntensity;
}
