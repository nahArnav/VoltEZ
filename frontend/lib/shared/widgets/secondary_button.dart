import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// Secondary action button — outlined cyan border.
/// Use for secondary CTAs: "Details", "Cancel", "Edit", etc.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isExpanded = false,
    this.icon,
    this.height = 52,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isExpanded;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTypography.buttonText,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(text),
          ],
        ),
      ),
    );

    if (isExpanded) return SizedBox(width: double.infinity, child: button);
    return button;
  }
}
