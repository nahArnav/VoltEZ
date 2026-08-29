import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Card matching the reference design: rich sage green gradient with subtle
/// lighter-green border, white text. Top slightly lighter, bottom slightly darker.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.accentColor,
    this.gradient,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.child,
    // Ignored params kept for API compatibility
    this.blur,
    this.tintOpacity,
    this.borderOpacity,
    this.frosted,
    this.opacity,
  });

  final Color? accentColor;
  final Gradient? gradient;
  final double? blur;
  final double? tintOpacity;
  final double? borderOpacity;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Widget? child;
  final bool? frosted;
  final double? opacity;

  @override
  Widget build(BuildContext context) {
    final bg = gradient ?? AppColors.primaryGradient;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1.0,
        ),
      ),
      child: child,
    );
  }
}
