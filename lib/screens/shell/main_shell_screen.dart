import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/ai_copilot_drawer.dart';

const Color _bg = Color(0xFF05090E);
const Color _panel = Color(0xFF0B141C);
const Color _cyan = Color(0xFF50F5FF);
const Color _lime = Color(0xFFC9FF58);
const Color _text = Color(0xFFF1F8FF);
const Color _muted = Color(0xFF7990A1);

class MainShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScaffold({
    super.key,
    required this.navigationShell,
  });

  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _buildFloatingBottomNav(context),
    );
  }

  Widget _buildFloatingBottomNav(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      height: 68,
      decoration: BoxDecoration(
        color: _panel.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _cyan.withOpacity(0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: _cyan.withOpacity(0.04),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.dashboard_rounded, "Overview"),
              _navItem(1, Icons.schedule_rounded, "Dispatch"),
              _centerCopilotButton(context),
              _navItem(2, Icons.account_balance_wallet_rounded, "Earnings"),
              _navItem(3, Icons.auto_awesome_rounded, "AI Insights"),
              _navItem(4, Icons.person_rounded, "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final bool isSelected = navigationShell.currentIndex == index;
    final Color activeColor = index == 3 ? _cyan : (index == 2 ? _lime : _cyan);

    return InkWell(
      onTap: () => _onTabSelected(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (isSelected)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeColor.withOpacity(0.12),
                    ),
                  ),
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? activeColor : _muted,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _text : _muted.withOpacity(0.8),
                fontSize: 8,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 4 : 0,
              height: 4,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerCopilotButton(BuildContext context) {
    return GestureDetector(
      onTap: () => AiCopilotSheet.show(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_cyan, _lime],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _cyan.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.bolt_rounded,
          color: Colors.black,
          size: 24,
        ),
      ),
    );
  }
}