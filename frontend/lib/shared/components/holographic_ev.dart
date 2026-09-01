import 'dart:math' as math;
import 'package:flutter/material.dart';

const Color holoBg = Color(0xFF070B12);
const Color holoSurface = Color(0xFF0D1525);
const Color holoCyan = Color(0xFF00F5FF);
const Color holoMint = Color(0xFF00FFA3);
const Color holoBlue = Color(0xFF3B82F6);
const Color holoPurple = Color(0xFF8B5CF6);
const Color holoText = Color(0xFFF8FAFC);
const Color holoMuted = Color(0xFF94A3B8);

/// A high-tech 3D holographic wireframe electric sports sedan
/// on an interactive cybernetic emitter pedestal.
class HolographicEv extends StatefulWidget {
  const HolographicEv({
    super.key,
    this.progress = 0.65,
    this.compact = false,
    this.showTelemetry = true,
  });

  final double progress;
  final bool compact;
  final bool showTelemetry;

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
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.compact ? 1.65 : 1.45,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final animVal = (_controller.value + widget.progress) % 1.0;

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 3D Canvas
                  CustomPaint(
                    size: Size(w, h),
                    painter: _CarHologramPainter(
                      t: animVal,
                      compact: widget.compact,
                    ),
                  ),

                  // Top Cybernetic Telemetry HUD
                  if (widget.showTelemetry)
                    Positioned(
                      top: widget.compact ? 4 : 8,
                      child: _TopTelemetryHud(
                        compact: widget.compact,
                        animValue: animVal,
                      ),
                    ),

                  // Floating Side Nodes when not compact
                  if (!widget.compact) ...[
                    Positioned(
                      left: 8,
                      top: h * 0.28,
                      child: _HudDataChip(
                        title: 'SYSTEM',
                        value: 'ONLINE',
                        color: holoMint,
                        icon: Icons.shield_outlined,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: h * 0.28,
                      child: _HudDataChip(
                        title: 'CHARGE RATE',
                        value: '145 kW',
                        color: holoCyan,
                        icon: Icons.bolt_rounded,
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: h * 0.12,
                      child: _HudDataChip(
                        title: 'POWER EFFICIENCY',
                        value: '98.4%',
                        color: holoBlue,
                        icon: Icons.speed_rounded,
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP HUD TELEMETRY WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _TopTelemetryHud extends StatelessWidget {
  const _TopTelemetryHud({
    required this.compact,
    required this.animValue,
  });

  final bool compact;
  final double animValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPulseDot(holoCyan),
            const SizedBox(width: 6),
            Text(
              'REACH: 342 km',
              style: TextStyle(
                color: holoCyan,
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontFamily: 'monospace',
                shadows: [
                  Shadow(color: holoCyan.withValues(alpha: 0.8), blurRadius: 10),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 1,
              height: 12,
              color: holoCyan.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 14),
            Text(
              'ETA: 1h 15m',
              style: TextStyle(
                color: holoMint,
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontFamily: 'monospace',
                shadows: [
                  Shadow(color: holoMint.withValues(alpha: 0.8), blurRadius: 10),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _buildPulseDot(holoMint),
          ],
        ),
      ],
    );
  }

  Widget _buildPulseDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.9),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _HudDataChip extends StatelessWidget {
  const _HudDataChip({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: holoBg.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: holoMuted.withValues(alpha: 0.8),
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3D HOLOGRAPHIC VECTOR & MESH CAR PAINTER — improved proportions
// ─────────────────────────────────────────────────────────────────────────────
class _CarHologramPainter extends CustomPainter {
  const _CarHologramPainter({
    required this.t,
    required this.compact,
  });

  final double t;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.56;
    final s = size.width / 380.0;

    // 1. Draw Base Hologram Pedestal
    _drawHolographicPedestal(canvas, cx, cy, s);

    // 2. Draw Top Arched HUD Ring
    _drawTopHudArcs(canvas, cx, cy - 78 * s, s);

    // 3. Draw 3D Sports Sedan Wireframe Body
    _draw3DSportsCarMesh(canvas, cx, cy, s);

    // 4. Draw Floating Holographic Particles & Energy Streams
    _drawHoloParticles(canvas, cx, cy, s);
  }

  void _drawHolographicPedestal(Canvas canvas, double cx, double cy, double s) {
    final baseCenter = Offset(cx, cy + 38 * s);

    // Outer glow oval
    canvas.drawOval(
      Rect.fromCenter(center: baseCenter, width: 330 * s, height: 80 * s),
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 28 * s)
        ..color = holoCyan.withValues(alpha: 0.28),
    );

    // Inner bright core
    canvas.drawOval(
      Rect.fromCenter(center: baseCenter, width: 210 * s, height: 50 * s),
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * s)
        ..color = holoMint.withValues(alpha: 0.35),
    );

    // Concentric Neon Calibration Rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s
      ..color = holoCyan.withValues(alpha: 0.55);

    final mintRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s
      ..color = holoMint.withValues(alpha: 0.85);

    // Outer Main Ring
    canvas.drawOval(
      Rect.fromCenter(center: baseCenter, width: 318 * s, height: 76 * s),
      ringPaint,
    );

    // Rotating Segmented Mint Ring
    final segRect = Rect.fromCenter(center: baseCenter, width: 272 * s, height: 64 * s);
    final rotAngle = t * 2 * math.pi;
    for (var i = 0; i < 6; i++) {
      final start = rotAngle + i * (math.pi / 3);
      canvas.drawArc(segRect, start, 0.35, false, mintRing);
    }

    // Inner Ring
    canvas.drawOval(
      Rect.fromCenter(center: baseCenter, width: 190 * s, height: 46 * s),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * s
        ..color = holoBlue.withValues(alpha: 0.6),
    );

    // Pedestal Ticks
    final tickPaint = Paint()
      ..color = holoCyan.withValues(alpha: 0.65)
      ..strokeWidth = 1.5 * s;

    for (var a = 0.0; a < 2 * math.pi; a += math.pi / 16) {
      final radX = 142 * s * math.cos(a + rotAngle * 0.5);
      final radY = 34 * s * math.sin(a + rotAngle * 0.5);
      final len = 6 * s;
      canvas.drawLine(
        Offset(baseCenter.dx + radX, baseCenter.dy + radY),
        Offset(baseCenter.dx + radX * (1 - len / 142), baseCenter.dy + radY * (1 - len / 34)),
        tickPaint,
      );
    }
  }

  void _drawTopHudArcs(Canvas canvas, double cx, double cy, double s) {
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s
      ..shader = LinearGradient(
        colors: [holoCyan, holoMint, holoCyan],
      ).createShader(Rect.fromLTWH(cx - 100 * s, cy - 20 * s, 200 * s, 40 * s));

    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + 10 * s), width: 220 * s, height: 60 * s),
      math.pi * 1.15,
      math.pi * 0.7,
      false,
      arcPaint,
    );

    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + 10 * s), width: 240 * s, height: 68 * s),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * s
        ..color = holoCyan.withValues(alpha: 0.35),
    );
  }

  void _draw3DSportsCarMesh(Canvas canvas, double cx, double cy, double s) {
    // ── Paints ──
    final meshLine = Paint()
      ..color = holoCyan.withValues(alpha: 0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * s;

    final brightLine = Paint()
      ..color = holoMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s;

    final accentLine = Paint()
      ..color = holoCyan.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * s;

    final darkFill = Paint()
      ..color = holoSurface.withValues(alpha: 0.70)
      ..style = PaintingStyle.fill;

    final glassFill = Paint()
      ..color = holoCyan.withValues(alpha: 0.13)
      ..style = PaintingStyle.fill;

    final bodyGradientFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          holoCyan.withValues(alpha: 0.20),
          holoMint.withValues(alpha: 0.10),
          holoBlue.withValues(alpha: 0.22),
        ],
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: 310 * s, height: 130 * s));

    // ── Realistic EV Sedan Key Points (Porsche Taycan / Lucid Air inspired) ──
    // 3/4 front-left view, slightly elevated viewpoint

    final ox = cx;
    final oy = cy - 4 * s;

    // ── FRONT END ──
    // Nose tip (front centre-low)
    final pNoseTip = Offset(ox - 144 * s, oy + 24 * s);
    // Front bumper lower corners
    final pBumperLow = Offset(ox - 146 * s, oy + 34 * s);
    final pBumperRear = Offset(ox - 108 * s, oy + 34 * s);

    // Front fascia upper edge
    final pFrontUpper = Offset(ox - 142 * s, oy + 14 * s);
    final pFrontUpperInner = Offset(ox - 108 * s, oy + 8 * s);

    // Headlight cluster (left – near side)
    final pHL1 = Offset(ox - 136 * s, oy + 16 * s);
    final pHL2 = Offset(ox - 124 * s, oy + 12 * s);
    final pHL3 = Offset(ox - 108 * s, oy + 10 * s);
    final pHL4 = Offset(ox - 108 * s, oy + 18 * s);

    // DRL strip (daytime running light)
    final pDRL1 = Offset(ox - 136 * s, oy + 22 * s);
    final pDRL2 = Offset(ox - 110 * s, oy + 16 * s);

    // ── HOOD / BONNET ──
    final pHoodFront = Offset(ox - 130 * s, oy + 6 * s);
    final pHoodMid = Offset(ox - 90 * s, oy - 4 * s);
    final pHoodRear = Offset(ox - 50 * s, oy - 10 * s);
    // Hood outer edge (left fender line)
    final pFenderFront = Offset(ox - 136 * s, oy + 8 * s);
    final pFenderMid = Offset(ox - 105 * s, oy + 2 * s);
    // Hood centre crease line
    final pHoodCrease1 = Offset(ox - 120 * s, oy + 4 * s);
    final pHoodCrease2 = Offset(ox - 60 * s, oy - 6 * s);

    // ── WINDSHIELD / CABIN ──
    final pABeltFront = Offset(ox - 46 * s, oy - 10 * s); // A-pillar base
    final pAPillarTop = Offset(ox - 28 * s, oy - 46 * s); // A-pillar top
    final pRoofFront = Offset(ox + 2 * s, oy - 52 * s);   // Roof front
    final pRoofPeak = Offset(ox + 48 * s, oy - 50 * s);   // Roof peak
    final pRoofRear = Offset(ox + 88 * s, oy - 42 * s);   // Roof rear
    final pCPillarTop = Offset(ox + 112 * s, oy - 26 * s); // C-pillar top

    // Windshield base right
    final pWindBase = Offset(ox + 8 * s, oy - 12 * s);

    // Side glass: upper & lower belt
    final pBeltFront = Offset(ox - 46 * s, oy - 10 * s);
    final pBeltMid = Offset(ox + 8 * s, oy - 12 * s);     // same as windBase
    final pBeltCPillar = Offset(ox + 108 * s, oy - 8 * s);

    // B-pillar (between front & rear window)
    final pBPillarTop = Offset(ox + 38 * s, oy - 50 * s);
    final pBPillarBot = Offset(ox + 40 * s, oy - 12 * s);

    // Rear quarter glass
    final pRearGlassTop = Offset(ox + 90 * s, oy - 40 * s);
    final pRearGlassBotFront = Offset(ox + 82 * s, oy - 10 * s);

    // ── REAR END ──
    final pTrunkTop = Offset(ox + 148 * s, oy - 16 * s);
    final pTailLightTop1 = Offset(ox + 152 * s, oy - 8 * s);
    final pTailLightTop2 = Offset(ox + 152 * s, oy + 6 * s);
    final pTailLightBot = Offset(ox + 148 * s, oy + 22 * s);
    final pRearBumper = Offset(ox + 140 * s, oy + 32 * s);
    final pRearBumperInner = Offset(ox + 100 * s, oy + 32 * s);

    // Rear spoiler / diffuser lip
    final pSpoilerLeft = Offset(ox + 110 * s, oy - 18 * s);
    final pSpoilerRight = Offset(ox + 152 * s, oy - 18 * s);

    // ── ROCKER PANEL / SILL ──
    final pSillFront = Offset(ox - 90 * s, oy + 34 * s);
    final pSillMid = Offset(ox + 22 * s, oy + 34 * s);
    final pSillRear = Offset(ox + 108 * s, oy + 30 * s);

    // ── CHARACTER LINES ──
    // Upper body crease (shoulder line)
    final pShoulderFront = Offset(ox - 110 * s, oy + 10 * s);
    final pShoulderMid = Offset(ox + 30 * s, oy + 8 * s);
    final pShoulderRear = Offset(ox + 130 * s, oy + 2 * s);

    // Lower door crease
    final pLowerCreaseFront = Offset(ox - 82 * s, oy + 28 * s);
    final pLowerCreaseMid = Offset(ox + 30 * s, oy + 26 * s);
    final pLowerCreaseRear = Offset(ox + 118 * s, oy + 22 * s);

    // ════════════════════════════════════════════════════════
    // 1. BODY FILL UNDERLAY
    // ════════════════════════════════════════════════════════
    final fullBody = Path()
      ..moveTo(pBumperLow.dx, pBumperLow.dy)
      ..lineTo(pNoseTip.dx, pNoseTip.dy)
      ..lineTo(pFrontUpper.dx, pFrontUpper.dy)
      ..lineTo(pHoodFront.dx, pHoodFront.dy)
      ..lineTo(pABeltFront.dx, pABeltFront.dy)
      ..lineTo(pAPillarTop.dx, pAPillarTop.dy)
      ..quadraticBezierTo(pRoofFront.dx, pRoofFront.dy, pRoofPeak.dx, pRoofPeak.dy)
      ..quadraticBezierTo(pRoofRear.dx, pRoofRear.dy, pCPillarTop.dx, pCPillarTop.dy)
      ..lineTo(pTrunkTop.dx, pTrunkTop.dy)
      ..lineTo(pTailLightTop1.dx, pTailLightTop1.dy)
      ..lineTo(pTailLightBot.dx, pTailLightBot.dy)
      ..lineTo(pRearBumper.dx, pRearBumper.dy)
      ..lineTo(pSillRear.dx, pSillRear.dy)
      ..lineTo(pSillMid.dx, pSillMid.dy)
      ..lineTo(pSillFront.dx, pSillFront.dy)
      ..close();

    canvas.drawPath(fullBody, darkFill);
    canvas.drawPath(fullBody, bodyGradientFill);

    // ════════════════════════════════════════════════════════
    // 2. WINDSHIELD
    // ════════════════════════════════════════════════════════
    final windshield = Path()
      ..moveTo(pABeltFront.dx, pABeltFront.dy)
      ..lineTo(pAPillarTop.dx, pAPillarTop.dy)
      ..quadraticBezierTo(pRoofFront.dx, pRoofFront.dy, pBPillarTop.dx, pBPillarTop.dy)
      ..lineTo(pBPillarBot.dx, pBPillarBot.dy)
      ..lineTo(pWindBase.dx, pWindBase.dy)
      ..close();
    canvas.drawPath(windshield, glassFill);
    canvas.drawPath(windshield, brightLine);

    // ════════════════════════════════════════════════════════
    // 3. FRONT SIDE WINDOW
    // ════════════════════════════════════════════════════════
    final frontWindow = Path()
      ..moveTo(pBPillarTop.dx, pBPillarTop.dy)
      ..quadraticBezierTo(pRoofPeak.dx, pRoofPeak.dy, pRearGlassTop.dx, pRearGlassTop.dy)
      ..lineTo(pRearGlassBotFront.dx, pRearGlassBotFront.dy)
      ..lineTo(pBeltCPillar.dx, pBeltCPillar.dy)
      ..lineTo(pBPillarBot.dx, pBPillarBot.dy)
      ..close();
    canvas.drawPath(frontWindow, glassFill);
    canvas.drawPath(frontWindow, meshLine);

    // B-pillar divider
    canvas.drawLine(pBPillarTop, pBPillarBot, meshLine);

    // ════════════════════════════════════════════════════════
    // 4. HOOD WIREFRAME GRID
    // ════════════════════════════════════════════════════════
    // Longitudinal hood lines
    canvas.drawLine(pFenderFront, pABeltFront, meshLine);
    canvas.drawLine(pHoodCrease1, pHoodCrease2, accentLine);
    // Lateral hood contour lines
    canvas.drawLine(
      Offset(ox - 118 * s, oy + 6 * s),
      Offset(ox - 80 * s, oy - 2 * s),
      accentLine,
    );
    canvas.drawLine(
      Offset(ox - 90 * s, oy + 0 * s),
      Offset(ox - 50 * s, oy - 8 * s),
      accentLine,
    );

    // Front bumper / air intake
    final intake = Path()
      ..moveTo(pNoseTip.dx, pNoseTip.dy)
      ..lineTo(pBumperLow.dx, pBumperLow.dy)
      ..lineTo(pBumperRear.dx, pBumperRear.dy)
      ..lineTo(pFrontUpperInner.dx, pFrontUpperInner.dy)
      ..close();
    canvas.drawPath(intake, meshLine);

    // ════════════════════════════════════════════════════════
    // 5. HEADLIGHT CLUSTER (neon lit)
    // ════════════════════════════════════════════════════════
    final headlightPath = Path()
      ..moveTo(pHL1.dx, pHL1.dy)
      ..lineTo(pHL2.dx, pHL2.dy)
      ..lineTo(pHL3.dx, pHL3.dy)
      ..lineTo(pHL4.dx, pHL4.dy)
      ..close();

    canvas.drawPath(
      headlightPath,
      Paint()
        ..color = holoMint.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      headlightPath,
      Paint()
        ..color = holoMint
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * s)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s,
    );
    canvas.drawPath(headlightPath, brightLine);

    // DRL signature strip
    canvas.drawLine(
      pDRL1,
      pDRL2,
      Paint()
        ..color = holoMint.withValues(alpha: 0.9)
        ..strokeWidth = 2.5 * s
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * s),
    );

    // ════════════════════════════════════════════════════════
    // 6. ROOFLINE / BODY OUTLINES (bright)
    // ════════════════════════════════════════════════════════
    canvas.drawPath(
      Path()
        ..moveTo(pABeltFront.dx, pABeltFront.dy)
        ..lineTo(pAPillarTop.dx, pAPillarTop.dy)
        ..quadraticBezierTo(pRoofFront.dx, pRoofFront.dy, pRoofPeak.dx, pRoofPeak.dy)
        ..quadraticBezierTo(pRoofRear.dx, pRoofRear.dy, pCPillarTop.dx, pCPillarTop.dy)
        ..lineTo(pTrunkTop.dx, pTrunkTop.dy),
      brightLine,
    );

    // ════════════════════════════════════════════════════════
    // 7. SHOULDER / CHARACTER LINES
    // ════════════════════════════════════════════════════════
    // Upper shoulder crease
    canvas.drawPath(
      Path()
        ..moveTo(pShoulderFront.dx, pShoulderFront.dy)
        ..quadraticBezierTo(
          pShoulderMid.dx, pShoulderMid.dy,
          pShoulderRear.dx, pShoulderRear.dy,
        ),
      meshLine,
    );

    // Lower door crease
    canvas.drawPath(
      Path()
        ..moveTo(pLowerCreaseFront.dx, pLowerCreaseFront.dy)
        ..quadraticBezierTo(
          pLowerCreaseMid.dx, pLowerCreaseMid.dy,
          pLowerCreaseRear.dx, pLowerCreaseRear.dy,
        ),
      accentLine,
    );

    // Rocker sill
    canvas.drawPath(
      Path()
        ..moveTo(pSillFront.dx, pSillFront.dy)
        ..lineTo(pSillMid.dx, pSillMid.dy)
        ..lineTo(pSillRear.dx, pSillRear.dy),
      meshLine,
    );

    // Vertical door panel grid lines (3 lines)
    for (var i = 1; i <= 3; i++) {
      final frac = i / 4.0;
      final top = Offset(
        pBeltFront.dx + (pBeltCPillar.dx - pBeltFront.dx) * frac,
        pBeltFront.dy + (pBeltCPillar.dy - pBeltFront.dy) * frac,
      );
      final bot = Offset(
        pSillFront.dx + (pSillRear.dx - pSillFront.dx) * frac,
        pSillFront.dy + (pSillRear.dy - pSillFront.dy) * frac,
      );
      canvas.drawLine(top, bot, accentLine);
    }

    // ════════════════════════════════════════════════════════
    // 8. REAR END — tail lights & spoiler
    // ════════════════════════════════════════════════════════
    // Spoiler
    canvas.drawLine(
      pSpoilerLeft,
      pSpoilerRight,
      Paint()
        ..color = holoCyan
        ..strokeWidth = 3 * s
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * s),
    );

    // Tail light cluster
    final tailLight = Path()
      ..moveTo(pTailLightTop1.dx, pTailLightTop1.dy)
      ..lineTo(pTailLightTop2.dx, pTailLightTop2.dy)
      ..lineTo(pTailLightBot.dx, pTailLightBot.dy)
      ..lineTo(Offset(pTailLightBot.dx - 8 * s, pTailLightBot.dy).dx,
               Offset(pTailLightBot.dx - 8 * s, pTailLightBot.dy).dy)
      ..close();
    canvas.drawPath(
      tailLight,
      Paint()
        ..color = const Color(0xFFFF3040).withValues(alpha: 0.4)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      tailLight,
      Paint()
        ..color = const Color(0xFFFF3040).withValues(alpha: 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * s)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s,
    );

    // Rear bumper line
    canvas.drawLine(
      pRearBumper,
      pRearBumperInner,
      meshLine,
    );

    // ════════════════════════════════════════════════════════
    // 9. WHEELS — detailed 3D perspective alloys
    // ════════════════════════════════════════════════════════
    _draw3DWheel(
      canvas,
      center: Offset(ox - 92 * s, oy + 34 * s),
      radiusX: 22 * s,
      radiusY: 24 * s,
      scale: s,
      spokes: 5,
    );

    _draw3DWheel(
      canvas,
      center: Offset(ox + 96 * s, oy + 30 * s),
      radiusX: 21 * s,
      radiusY: 23 * s,
      scale: s,
      spokes: 5,
    );

    // ════════════════════════════════════════════════════════
    // 10. CHARGING PORT with energy pulse
    // ════════════════════════════════════════════════════════
    final chargePort = Offset(ox - 52 * s, oy + 14 * s);
    final portPulse = Paint()
      ..color = holoMint.withValues(alpha: 0.65 + 0.35 * math.sin(t * math.pi * 4))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(chargePort, 4.5 * s, portPulse);
    canvas.drawCircle(
      chargePort,
      8.5 * s,
      Paint()
        ..color = holoMint.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s,
    );

    // Glowing charge cable
    final cable = Path()
      ..moveTo(chargePort.dx, chargePort.dy)
      ..cubicTo(
        chargePort.dx - 20 * s, chargePort.dy + 20 * s,
        chargePort.dx - 45 * s, chargePort.dy + 38 * s,
        ox - 110 * s, cy + 38 * s,
      );

    canvas.drawPath(
      cable,
      Paint()
        ..color = holoMint.withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * s,
    );
  }

  void _draw3DWheel(
    Canvas canvas, {
    required Offset center,
    required double radiusX,
    required double radiusY,
    required double scale,
    required int spokes,
  }) {
    final s = scale;

    // Tyre fill
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      Paint()..color = holoBg,
    );

    // Tyre outer ring – thick neon edge
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      Paint()
        ..color = holoCyan.withValues(alpha: 0.80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * s,
    );

    // Inner tyre groove
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 1.75, height: radiusY * 1.75),
      Paint()
        ..color = holoCyan.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * s,
    );

    // Alloy rim ring
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 1.4, height: radiusY * 1.4),
      Paint()
        ..color = holoMint.withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * s,
    );

    // Centre hub cap
    canvas.drawCircle(
      center,
      4.0 * s,
      Paint()..color = holoMint,
    );
    canvas.drawCircle(
      center,
      4.0 * s,
      Paint()
        ..color = holoMint.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * s),
    );

    // Rotating turbine spokes
    final spokeAngle = t * 2 * math.pi;
    final spokePaint = Paint()
      ..color = holoCyan.withValues(alpha: 0.85)
      ..strokeWidth = 1.4 * s
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < spokes; i++) {
      final a = spokeAngle + (i * 2 * math.pi / spokes);
      final sx = center.dx + (radiusX * 0.68) * math.cos(a);
      final sy = center.dy + (radiusY * 0.68) * math.sin(a);
      canvas.drawLine(center, Offset(sx, sy), spokePaint);
    }

    // Brake calliper (small rectangle visible through spokes)
    final calliperRect = Rect.fromCenter(
      center: Offset(center.dx - radiusX * 0.4, center.dy),
      width: 8 * s,
      height: 5 * s,
    );
    canvas.drawRect(
      calliperRect,
      Paint()
        ..color = holoPurple.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawHoloParticles(Canvas canvas, double cx, double cy, double s) {
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 20; i++) {
      final phase = (t + i / 20.0) % 1.0;
      final angle = i * (2 * math.pi / 20) + t * math.pi;
      final radius = 90 * s + (i % 5) * 20 * s;
      final px = cx + radius * math.cos(angle);
      final py = cy + 18 * s - phase * 80 * s + (i % 3) * 14 * s;

      final alpha = math.sin(phase * math.pi) * 0.60;
      particlePaint.color = (i % 2 == 0 ? holoCyan : holoMint).withValues(alpha: alpha.clamp(0.0, 1.0));

      canvas.drawCircle(Offset(px, py), (1.4 + (i % 3) * 0.6) * s, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CarHologramPainter oldDelegate) => true;
}
