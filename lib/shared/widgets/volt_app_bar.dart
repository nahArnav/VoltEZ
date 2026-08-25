import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// VoltEZ consistent app bar with back button.
/// Use this on EVERY non-home screen so back navigation is always obvious.
class VoltAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VoltAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions,
    this.showBack = true,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool showBack;
  final Color? backgroundColor;

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 72 : 56);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? AppColors.background,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  onPressed: onBack ?? () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/driver/home');
                    }
                  },
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                  tooltip: 'Back',
                  splashRadius: 24,
                )
              else
                const SizedBox(width: 8),
              Expanded(
                child: subtitle != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.headlineLarge.copyWith(fontSize: 18),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            subtitle!,
                            style: AppTypography.bodySmall.copyWith(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: AppTypography.headlineLarge.copyWith(fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}
