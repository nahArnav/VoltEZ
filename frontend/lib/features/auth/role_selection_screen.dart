import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../shared/models/models.dart';

/// Role selection screen — shown after signup to choose Driver or Business.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              SizedBox(
                width: 140,
                height: 70,
                child: SvgPicture.asset(
                  'assets/images/VoltEZ_logo.svg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Text('How will you use VoltEZ?', style: AppTypography.displaySmall),
              const SizedBox(height: 8),
              const Text(
                'Choose your role to get started.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const Spacer(),
              _RoleOption(
                icon: Icons.directions_car_rounded,
                title: 'I drive an EV',
                subtitle: 'Find chargers, plan routes, book slots.',
                color: AppColors.primary,
                onTap: () {
                  context.read<AuthProvider>().setRole(AccountRole.driver);
                  context.go('/driver/home');
                },
              ),
              const SizedBox(height: 16),
              _RoleOption(
                icon: Icons.ev_station_rounded,
                title: 'I own chargers',
                subtitle: 'Manage your charging business.',
                color: AppColors.success,
                onTap: () {
                  context.read<AuthProvider>().setRole(AccountRole.owner);
                  context.go('/business/dashboard');
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.headlineMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTypography.bodySmall),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
