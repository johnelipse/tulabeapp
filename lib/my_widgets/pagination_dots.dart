import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PaginationDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final ValueChanged<int>? onTap;

  const PaginationDots({
    super.key,
    required this.count,
    required this.activeIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final bool isActive = index == activeIndex;
        return GestureDetector(
          onTap: () => onTap?.call(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: isActive ? 24 : 8,
            height: 3,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.textTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
