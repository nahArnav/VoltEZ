import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 4000);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );

  Timer? _navigationTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_navigationTimer != null) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _goToLogin();
      return;
    }

    _controller.forward();

    _navigationTimer = Timer(
      _duration + const Duration(milliseconds: 400),
      _goToLogin,
    );
  }

  void _goToLogin() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
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
  return Scaffold(
    backgroundColor: _Colors.background,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(
          painter: _GridPainter(),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxHeight < 650;

                    return Column(
                      children: [
                        _Header(controller: _controller),

                        Expanded(
                          child: Center(
                            child: Transform.scale(
                              scale: isCompact ? 0.82 : 1.0,
                              child: _HolographicCore(
                                controller: _controller,
                              ),
                            ),
                          ),
                        ),

                        _BootStatus(controller: _controller),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    )     
  );
}
} // closes _SplashScreenState

abstract final class _Colors {
  static const background = Color(0xFF050A12);
  ...
}
          
abstract final class _Colors {
  static const background = Color(0xFF050A12);
  static const panel = Color(0xFF0D1722);

  static const cyan = Color(0xFF00E5FF);
  static const blue = Color(0xFF4D8DFF);
  static const violet = Color(0xFF8B6CFF);
  static const green = Color(0xFF34D399);

  static const text = Color(0xFFF1F8FF);
  static const muted = Color(0xFF7F95A7);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
  });

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final opacity = _progress(
          controller.value,
          0,
          .15,
        );

        final percentage =
            (controller.value * 100).round().clamp(0, 100);

        return Opacity(
          opacity: opacity,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _Colors.green,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 9),

              const Text(
                'VOLTEZ / AI MOBILITY OS',
                style: TextStyle(
                  color: _Colors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),

              const Spacer(),

              Text(
                '$percentage%',
                style: const TextStyle(
                  color: _Colors.cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HolographicCore extends StatelessWidget {
  const _HolographicCore({
    required this.controller,
  });

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final size = math.min(
      MediaQuery.sizeOf(context).width - 48,
      340.0,
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final appear = _progress(
          controller.value,
          .05,
          .42,
          curve: Curves.easeOutBack,
        );

        final energy = _progress(
          controller.value,
          .15,
          .95,
        );

        return Opacity(
          opacity: appear,
          child: Transform.scale(
            scale: .75 + (.25 * appear),
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.square(size),
                    painter: _CorePainter(
                      progress: energy,
                    ),
                  ),

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [
                              _Colors.cyan,
                              _Colors.blue,
                              _Colors.green,
                            ],
                          ).createShader(bounds);
                        },
                        child: const Text(
                          'VOLTEZ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'INTELLIGENT EV CHARGING',
                        style: TextStyle(
                          color: _Colors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),

                      const SizedBox(height: 20),

                      _TelemetryRing(
                        progress: energy,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TelemetryRing extends StatelessWidget {
  const _TelemetryRing({
    required this.progress,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor:
                _Colors.cyan.withValues(alpha: .08),
            valueColor: const AlwaysStoppedAnimation(
              _Colors.cyan,
            ),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: _Colors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'ENERGY',
                style: TextStyle(
                  color: _Colors.muted,
                  fontSize: 7,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BootStatus extends StatelessWidget {
  const _BootStatus({
    required this.controller,
  });

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final appear = _progress(
          controller.value,
          .35,
          .72,
        );

        final progress = _progress(
          controller.value,
          .10,
          .95,
        );

        return Opacity(
          opacity: appear,
          child: Transform.translate(
            offset: Offset(
              0,
              18 * (1 - appear),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _Colors.panel.withValues(alpha: .88),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _Colors.cyan.withValues(alpha: .22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _Colors.cyan.withValues(alpha: .07),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: _Colors.green,
                        size: 18,
                      ),

                      const SizedBox(width: 8),

                      Text(
                        _status(progress),
                        style: const TextStyle(
                          color: _Colors.text,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .7,
                        ),
                      ),

                      const Spacer(),

                      const Icon(
                        Icons.electric_car_rounded,
                        color: _Colors.cyan,
                        size: 20,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 5,
                      child: Stack(
                        children: [
                          Container(
                            color: _Colors.text
                                .withValues(alpha: .08),
                          ),

                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _Colors.violet,
                                    _Colors.cyan,
                                    _Colors.green,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 13),

                  const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      _Metric(
                        title: 'FLEET',
                        value: 'CONNECTED',
                      ),
                      _Metric(
                        title: 'CHARGERS',
                        value: 'ONLINE',
                      ),
                      _Metric(
                        title: 'AI',
                        value: 'READY',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _Colors.muted,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: _Colors.cyan,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _Colors.cyan.withValues(alpha: .035)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          _Colors.cyan.withValues(alpha: .10),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: size.width * .75,
        ),
      );

    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * .75,
      glow,
    );
  }

  @override
  bool shouldRepaint(
    covariant _GridPainter oldDelegate,
  ) {
    return false;
  }
}

class _EnergyNetworkPainter extends CustomPainter {
  const _EnergyNetworkPainter({
    required this.progress,
  });

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width * .5,
      size.height * .46,
    );

    final radius =
        math.min(size.width, size.height) * .42;

    final opacity = _progress(
      progress,
      .10,
      .70,
    );

    final line = Paint()
      ..color =
          _Colors.violet.withValues(alpha: .14 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final dot = Paint()
      ..color =
          _Colors.cyan.withValues(alpha: .6 * opacity);

    final nodes = List.generate(
      10,
      (index) {
        final angle =
            index * math.pi * 2 / 10 -
                math.pi / 2;

        return center +
            Offset(
              math.cos(angle) * radius,
              math.sin(angle) *
                  radius *
                  .62,
            );
      },
    );

    for (var i = 0; i < nodes.length; i++) {
      canvas.drawLine(
        nodes[i],
        nodes[(i + 2) % nodes.length],
        line,
      );

      canvas.drawCircle(
        nodes[i],
        2,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _EnergyNetworkPainter oldDelegate,
  ) {
    return oldDelegate.progress != progress;
  }
}

class _CorePainter extends CustomPainter {
  const _CorePainter({
    required this.progress,
  });

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          _Colors.cyan.withValues(
            alpha: .18 * progress,
          ),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
      );

    canvas.drawCircle(
      center,
      radius,
      glow,
    );

    for (var i = 0; i < 4; i++) {
      final ringRadius =
          radius * (.38 + i * .14);

      final paint = Paint()
        ..color = (i.isEven
                ? _Colors.cyan
                : _Colors.violet)
            .withValues(
              alpha: .22 + i * .06,
            )
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 3 ? 2 : 1;

      final sweep =
          math.pi * (1.15 + progress);

      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: ringRadius,
        ),
        -math.pi / 2 + i * .7,
        sweep,
        false,
        paint,
      );
    }

    final angle =
        -math.pi / 2 +
            math.pi * 2 * progress;

    canvas.drawCircle(
      center +
          Offset(
            math.cos(angle) *
                radius *
                .8,
            math.sin(angle) *
                radius *
                .52,
          ),
      4,
      Paint()..color = _Colors.green,
    );

    canvas.drawCircle(
      center,
      radius * .22 * progress,
      Paint()
        ..color = _Colors.cyan.withValues(
          alpha: .10,
        ),
    );
  }

  @override
  bool shouldRepaint(
    covariant _CorePainter oldDelegate,
  ) {
    return oldDelegate.progress != progress;
  }
}

String _status(double progress) {
  if (progress < .25) {
    return 'INITIALIZING ENERGY GRID';
  }

  if (progress < .55) {
    return 'SCANNING CHARGING NETWORK';
  }

  if (progress < .82) {
    return 'SYNCHRONIZING EV SYSTEMS';
  }

  return 'SYSTEM READY • LET’S MOVE';
}

double _progress(
  double value,
  double begin,
  double end, {
  Curve curve = Curves.easeOutCubic,
}) {
  return Interval(
    begin,
    end,
    curve: curve,
  ).transform(value).clamp(0.0, 1.0).toDouble();
}