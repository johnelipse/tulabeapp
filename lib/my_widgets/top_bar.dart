import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TopBar extends StatelessWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationTap;

  const TopBar({
    super.key,
    this.onSearchTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _Logo(),
        const Spacer(),
        GestureDetector(
          onTap: onSearchTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onNotificationTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none, color: AppColors.textPrimary, size: 20),
              ),
              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.orangeAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        children: [
          TextSpan(text: 'TU', style: TextStyle(color: AppColors.primary)),
          TextSpan(text: 'LABE', style: TextStyle(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
