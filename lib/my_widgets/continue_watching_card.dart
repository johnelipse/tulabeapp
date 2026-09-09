import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ContinueWatchingCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final double progress;
  final int remainingSeconds;
  final VoidCallback? onTap;

  const ContinueWatchingCard({
    super.key,
    required this.title,
    this.imageUrl,
    required this.progress,
    required this.remainingSeconds,
    this.onTap,
  });

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}m ${s}s left';
    return '${s}s left';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: imageUrl != null
                        ? Image.network(imageUrl!, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.surface,
                            child: const Icon(Icons.play_arrow, color: AppColors.textTertiary),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      color: Colors.white.withValues(alpha: 0.2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            color: AppColors.primary,
                            height: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        _formatTime(remainingSeconds),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$pct% watched',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
