import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/login_screen.dart';

/// A premium, motion-aware launch screen for Voltez.
///
/// Compatible with Flutter 3.47.1. It intentionally avoids deprecated color
/// opacity APIs and respects the platform's "reduce motion" setting.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 2400);
  static const _holdDuration = Duration(milliseconds: 420);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _animationDuration,
  );
  Timer? _navigationTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_navigationTimer != null) return;

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.value = 1;
      _goToLogin();
      return;
    }

    _controller.forward();
    _navigationTimer = Timer(_animationDuration + _holdDuration, _goToLogin);
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 650;

    return Scaffold(
      backgroundColor: _Palette.paper,
      body: Semantics(
        label: 'Voltez is loading',
        child: Stack(
          children: [
            const Positioned.fill(child: RepaintBoundary(child: _PaperGrain())),
            const _AmbientField(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Column(
                  children: [
                    _PageFurniture(controller: _controller),
                    const Spacer(),
                    _LaunchMark(controller: _controller, compact: compact),
                    const Spacer(flex: 2),
                    _Footer(controller: _controller),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class _Palette {
  // Shared AI-mobility palette from the login portal.
  static const paper = Color(0xFF05090E);
  static const ink = Color(0xFFF1F8FF);
  static const forest = Color(0xFF50F5FF);
  static const rust = Color(0xFFC9FF58);
  static const mutedInk = Color(0xFF7990A1);
  static const electric = Color(0xFF50F5FF);
}

class _PageFurniture extends StatelessWidget {
  const _PageFurniture({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = _interval(controller.value, 0, .18);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, -10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _MicroLabel('SIH ’26  /  PS-04'),
          _MicroLabel('POWERING POSSIBILITY'),
        ],
      ),
    );
  }
}

class _MicroLabel extends StatelessWidget {
  const _MicroLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _Palette.mutedInk,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.45,
        ),
      );
}

class _LaunchMark extends StatelessWidget {
  const _LaunchMark({required this.controller, required this.compact});

  final AnimationController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 82.0 : 108.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) => SizedBox.square(
            dimension: markSize,
            child: CustomPaint(
              painter: _BoltPainter(progress: _interval(controller.value, 0, .48)),
            ),
          ),
        ),
        SizedBox(height: compact ? 22 : 32),
        _KineticWord(controller: controller),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final t = _interval(controller.value, .48, .69);
            return Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
            );
          },
          child: const Text(
            'NEURAL ENERGY NETWORK',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _Palette.rust,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.65,
            ),
          ),
        ),
      ],
    );
  }
}

class _KineticWord extends StatelessWidget {
  const _KineticWord({required this.controller});
  final AnimationController controller;
  static const _word = 'VOLTEZ';

  @override
  Widget build(BuildContext context) {
    final fontSize = math.min(MediaQuery.sizeOf(context).width * .125, 52.0);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_word.length, (index) {
            final start = .16 + index * .055;
            final t = _interval(controller.value, start, start + .31,
                curve: Curves.easeOutBack);
            return Transform.translate(
              offset: Offset(0, 28 * (1 - t)),
              child: Transform.rotate(
                angle: -.34 * (1 - t),
                child: Opacity(
                  opacity: t,
                  child: Text(
                    _word[index],
                    style: TextStyle(
                      color: _Palette.ink,
                      fontSize: fontSize,
                      height: .88,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.4,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = _interval(controller.value, .52, .98);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - t)),
              child: Column(
                children: [
                  _ChargeMeter(progress: _interval(controller.value, .16, .92)),
                  const SizedBox(height: 22),
                  const Text(
                    'Syncing intelligent journeys\nfor every electric mile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _Palette.mutedInk,
                      fontSize: 13,
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _ChargeMeter extends StatelessWidget {
  const _ChargeMeter({required this.progress});
  final double progress;
  static const _count = 19;

  @override
  Widget build(BuildContext context) {
    final filled = (progress * _count).floor();
    return SizedBox(
      width: 214,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_count, (index) {
          final active = index < filled;
          return TweenAnimationBuilder<double>(
            tween: Tween(end: active ? 1 : 0),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            builder: (context, value, _) => Transform.rotate(
              angle: -.16,
              child: Container(
                width: 5,
                height: 7 + 9 * value,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    _Palette.mutedInk.withValues(alpha: .22),
                    _Palette.forest,
                    value,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AmbientField extends StatelessWidget {
  const _AmbientField();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -140,
              right: -120,
              child: _Glow(color: _Palette.electric.withValues(alpha: .28), size: 290),
            ),
            Positioned(
              bottom: -130,
              left: -90,
              child: _Glow(color: _Palette.rust.withValues(alpha: .08), size: 260),
            ),
          ],
        ),
      );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _BoltPainter extends CustomPainter {
  const _BoltPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    final path = Path()
      ..moveTo(59 * scale, 3 * scale)
      ..lineTo(20 * scale, 55 * scale)
      ..lineTo(45 * scale, 55 * scale)
      ..lineTo(33 * scale, 98 * scale)
      ..lineTo(81 * scale, 41 * scale)
      ..lineTo(53 * scale, 41 * scale)
      ..close();
    final guide = Paint()
      ..color = _Palette.ink.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, guide);

    final ink = Paint()
      ..color = _Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final metric = path.computeMetrics().single;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), ink);
    if (progress > .9) {
      canvas.drawCircle(Offset(33 * scale, 97 * scale), 3.5, Paint()..color = _Palette.rust);
    }
  }

  @override
  bool shouldRepaint(covariant _BoltPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PaperGrain extends StatelessWidget {
  const _PaperGrain();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PaperGrainPainter());
}

class _PaperGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var seed = 483;
    int next() => seed = (seed * 1664525 + 1013904223) & 0x7fffffff;
    final paint = Paint()..color = _Palette.ink.withValues(alpha: .025);
    final count = (size.width * size.height / 2200).round();
    for (var index = 0; index < count; index++) {
      canvas.drawCircle(
        Offset((next() % size.width.ceil()).toDouble(), (next() % size.height.ceil()).toDouble()),
        .55,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter oldDelegate) => false;
}

double _interval(double value, double begin, double end,
        {Curve curve = Curves.easeOutCubic}) =>
    Interval(begin, end, curve: curve)
        .transform(value)
        .clamp(0.0, 1.0)
        .toDouble();
