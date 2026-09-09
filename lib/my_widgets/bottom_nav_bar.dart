import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onMenuTap;
  final bool menuActive;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onMenuTap,
    this.menuActive = false,
  });

  static const _items = [
    _NavItemData(icon: Icons.home_rounded, label: 'Home', activeIcon: Icons.home_rounded),
    _NavItemData(icon: Icons.movie_outlined, label: 'Movies', activeIcon: Icons.movie),
    _NavItemData(icon: Icons.live_tv_outlined, label: 'Series', activeIcon: Icons.live_tv),
    _NavItemData(icon: Icons.playlist_play_outlined, label: 'Playlists', activeIcon: Icons.playlist_play),
  ];

  @override
  Widget build(BuildContext context) {
    // Mirrors the web's liquid-glass bottom bar: a translucent panel with a
    // backdrop blur, glass shadow, and a specular sheen along the top.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0x8C0A0118),
            boxShadow: [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 32,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Color(0x59FFFFFF),
                blurRadius: 0,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color(0x2E000000),
                blurRadius: 0,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Specular sheen along the top.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 30,
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x24FFFFFF),
                          Color(0x0AFFFFFF),
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.18, 0.45],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ...List.generate(_items.length, (index) {
                        final bool isActive = index == currentIndex;
                        final item = _items[index];
                        return _NavItem(
                          icon: isActive ? item.activeIcon : item.icon,
                          label: item.label,
                          isActive: isActive,
                          onTap: () => onTap(index),
                        );
                      }),
                      _NavItem(
                        icon: menuActive ? Icons.close : Icons.menu_rounded,
                        label: 'Menu',
                        isActive: menuActive,
                        onTap: onMenuTap,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : AppColors.textTertiary,
              size: 22,
              shadows: isActive
                  ? const [
                      Shadow(color: AppColors.primary, blurRadius: 8),
                    ]
                  : null,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.textTertiary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  final IconData activeIcon;
  const _NavItemData({required this.icon, required this.label, required this.activeIcon});
}
