import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class YearChip extends StatelessWidget {
  final int year;
  final VoidCallback? onTap;

  const YearChip({
    super.key,
    required this.year,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            year.toString(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
