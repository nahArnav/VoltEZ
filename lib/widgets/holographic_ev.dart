import 'dart:math' as math;
import 'package:flutter/material.dart';

const Color holoCyan = Color(0xFF00E5FF);
const Color holoEmerald = Color(0xFF00E676);
const Color holoText = Color(0xFFF1F5F9);
const Color holoMuted = Color(0xFF94A3B8);
const Color holoBg = Color(0xFF0A0E17);
const Color holoSurface = Color(0xFF131B2A);

class HolographicEv extends StatefulWidget {
  final double progress;
  final bool compact;

  const HolographicEv({
    super.key,
    this.progress = 0.87,
    this.compact = false,
  });

  @override
  State<HolographicEv> createState() => _HolographicEvState();
}

class _HolographicEvState extends State<HolographicEv>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.compact ? 260.0 : 320.0;
    final height = widget.compact ? 220.0 : 260.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            size: Size(width, height),
            painter: _FullHologramCarPainter(
              anim: _controller.value,
              progress: widget.progress,
            ),
          ),
        );
      },
    );
  }
}

class _FullHologramCarPainter extends CustomPainter {
  final double anim;
  final double progress;

  _FullHologramCarPainter({required this.anim, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.54);

    // 1. Glowing Floor Platform & Rings
    _drawFloorHUD(canvas, center, size.width * 0.44);

    // 2. Isometric Wireframe Sports Car
    _drawWireframeSedan(canvas, center, size.width * 0.88);

    // 3. Laser Scan & Particle FX
    _drawLaserFX(canvas, size);
  }

  void _drawFloorHUD(Canvas canvas, Offset center, double radius) {
    final floorCenter = center + const Offset(0, 32);

    // Ambient Floor Glow
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          holoCyan.withValues(alpha: 0.32),
          holoEmerald.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: floorCenter, radius: radius * 1.3));
    canvas.drawOval(
      Rect.fromCenter(center: floorCenter, width: radius * 2.5, height: radius * 0.95),
      glow,
    );

    canvas.save();
    canvas.translate(floorCenter.dx, floorCenter.dy);

    final rot = anim * 2 * math.pi;

    // Segmented Rotating Outer Ring
    final segPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    for (int i = 0; i < 20; i++) {
      final a = rot + (i * math.pi / 10);
      segPaint.color = (i % 2 == 0 ? holoCyan : holoEmerald).withValues(alpha: 0.55);
      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: radius * 2.2, height: radius * 0.78),
        a,
        math.pi / 28,
        false,
        segPaint,
      );
    }

    // Inner Base Ring
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = holoCyan.withValues(alpha: 0.4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radius * 1.7, height: radius * 0.6),
      innerPaint,
    );

    // Active Progress Floor Ring
    final activeRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0
      ..color = holoEmerald;

    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: radius * 1.88, height: radius * 0.66),
      -rot,
      progress * 2 * math.pi,
      false,
      activeRing,
    );

    canvas.restore();
  }

  void _drawWireframeSedan(Canvas canvas, Offset center, double carWidth) {
    final scale = carWidth / 260.0;
    final c = center + const Offset(0, -6);

    Offset p(double x, double y) => Offset(c.dx + x * scale, c.dy + y * scale);

    final line = Paint()
      ..color = holoCyan.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final boldLine = Paint()
      ..color = holoCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final accent = Paint()
      ..color = holoEmerald
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final fill = Paint()
      ..color = holoCyan.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    // --- CAR WIREFRAME VERTICES ---
    // Hood & Bumper
    final pNoseL = p(-95, 12);
    final pNoseR = p(-65, -8);
    final pNoseC = p(-78, 22);
    final pHoodBaseL = p(-35, 20);
    final pHoodBaseR = p(-15, -16);

    // Cabin / Roof
    final pWindshieldTopL = p(5, -28);
    final pWindshieldTopR = p(20, -42);
    final pRoofBackL = p(65, -24);
    final pRoofBackR = p(75, -36);

    // Rear / Trunk
    final pTrunkL = p(95, -6);
    final pTrunkR = p(102, -18);
    final pTailL = p(98, 8);

    // Lower Side Sill & Wheels
    final pFrontWheelC = p(-48, 30);
    final pRearWheelC = p(58, 20);
    final pSillFront = p(-70, 28);
    final pSillMid = p(5, 26);
    final pSillRear = p(85, 16);

    // 1. Hood Polygon
    final hoodPath = Path()
      ..moveTo(pNoseL.dx, pNoseL.dy)
      ..lineTo(pNoseR.dx, pNoseR.dy)
      ..lineTo(pHoodBaseR.dx, pHoodBaseR.dy)
      ..lineTo(pHoodBaseL.dx, pHoodBaseL.dy)
      ..close();
    canvas.drawPath(hoodPath, fill);
    canvas.drawPath(hoodPath, boldLine);

    // 2. Windshield
    final windshield = Path()
      ..moveTo(pHoodBaseL.dx, pHoodBaseL.dy)
      ..lineTo(pHoodBaseR.dx, pHoodBaseR.dy)
      ..lineTo(pWindshieldTopR.dx, pWindshieldTopR.dy)
      ..lineTo(pWindshieldTopL.dx, pWindshieldTopL.dy)
      ..close();
    canvas.drawPath(windshield, fill);
    canvas.drawPath(windshield, line);

    // 3. Roof Canopy
    final roof = Path()
      ..moveTo(pWindshieldTopL.dx, pWindshieldTopL.dy)
      ..lineTo(pWindshieldTopR.dx, pWindshieldTopR.dy)
      ..lineTo(pRoofBackR.dx, pRoofBackR.dy)
      ..lineTo(pRoofBackL.dx, pRoofBackL.dy)
      ..close();
    canvas.drawPath(roof, fill);
    canvas.drawPath(roof, line);

    // 4. Rear Window & Trunk
    final rearGlass = Path()
      ..moveTo(pRoofBackL.dx, pRoofBackL.dy)
      ..lineTo(pRoofBackR.dx, pRoofBackR.dy)
      ..lineTo(pTrunkR.dx, pTrunkR.dy)
      ..lineTo(pTrunkL.dx, pTrunkL.dy)
      ..close();
    canvas.drawPath(rearGlass, line);

    // 5. Side Body Panels & Doors
    final sideBelt = Path()
      ..moveTo(pNoseL.dx, pNoseL.dy)
      ..lineTo(pHoodBaseL.dx, pHoodBaseL.dy)
      ..lineTo(pTrunkL.dx, pTrunkL.dy)
      ..lineTo(pTailL.dx, pTailL.dy)
      ..lineTo(pSillRear.dx, pSillRear.dy)
      ..lineTo(pSillMid.dx, pSillMid.dy)
      ..lineTo(pSillFront.dx, pSillFront.dy)
      ..lineTo(pNoseC.dx, pNoseC.dy)
      ..close();
    canvas.drawPath(sideBelt, accent);

    // B-Pillar & Door Seams
    canvas.drawLine(p(35, -26), p(25, 24), line); // B Pillar
    canvas.drawLine(pWindshieldTopL, pHoodBaseL, line); // A Pillar
    canvas.drawLine(pRoofBackL, pTrunkL, line); // C Pillar
    canvas.drawLine(pHoodBaseL, p(0, 24), line); // Front Door cut

    // Longitudinal Hood Lines (Aerodynamic ribs)
    canvas.drawLine(p(-85, 4), p(-25, -2), line);
    canvas.drawLine(p(-80, 10), p(-20, 6), line);

    // Front Bumper / Honeycomb Grille
    canvas.drawLine(pNoseL, pNoseC, boldLine);
    canvas.drawLine(pNoseC, p(-60, 26), boldLine);
    canvas.drawLine(pNoseR, p(-50, -4), line);

    // Headlight Glow (Front Left)
    final headlight = Path()
      ..moveTo(pNoseL.dx, pNoseL.dy)
      ..lineTo(p(-75, 14).dx, p(-75, 14).dy)
      ..lineTo(pNoseC.dx, pNoseC.dy);
    canvas.drawPath(headlight, Paint()..color = holoEmerald..style = PaintingStyle.stroke..strokeWidth = 2.4);

    // --- 3D WHEELS (Isometric Ellipses with Alloy Spokes) ---
    void drawWheel(Offset pos, double r) {
      final rim = Paint()
        ..color = holoEmerald
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      canvas.drawOval(Rect.fromCenter(center: pos, width: r * 1.6, height: r * 2.2), rim);

      final inner = Paint()
        ..color = holoCyan.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawOval(Rect.fromCenter(center: pos, width: r * 1.0, height: r * 1.4), inner);

      // Rotating Spokes
      for (int i = 0; i < 5; i++) {
        final a = (i * 2 * math.pi / 5) + (anim * 2 * math.pi);
        final spokeEnd = pos + Offset(math.cos(a) * r * 0.7, math.sin(a) * r * 0.95);
        canvas.drawLine(pos, spokeEnd, inner);
      }
    }

    drawWheel(pFrontWheelC, 13 * scale);
    drawWheel(pRearWheelC, 12 * scale);
  }

  void _drawLaserFX(Canvas canvas, Size size) {
    // Holographic Scanning Beam
    final scanY = size.height * 0.32 + (math.sin(anim * 2 * math.pi) * (size.height * 0.22));

    final laser = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          holoCyan.withValues(alpha: 0.8),
          holoEmerald,
          holoCyan.withValues(alpha: 0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, scanY, size.width, 2.5))
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(size.width * 0.1, scanY), Offset(size.width * 0.9, scanY), laser);

    // Floating Sparks / Hologram Data Nodes
    final pPaint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(42);

    for (int i = 0; i < 14; i++) {
      final px = size.width * (0.15 + rng.nextDouble() * 0.7);
      final initialY = size.height * (0.2 + rng.nextDouble() * 0.6);
      final py = (initialY - (anim * 70 * (i % 3 + 1))) % (size.height * 0.85);

      pPaint.color = (i % 2 == 0 ? holoCyan : holoEmerald).withValues(
        alpha: (0.3 + 0.6 * math.sin((anim * 2 + i) * math.pi)).clamp(0.0, 1.0),
      );

      canvas.drawCircle(Offset(px, py), 1.2, pPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FullHologramCarPainter old) =>
      old.anim != anim || old.progress != progress;
}