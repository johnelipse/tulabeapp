import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Quality picker shown when a movie has 2+ ready qualities — mirrors the web
/// `components/shared/quality-picker-modal.tsx`. Pops with the chosen quality
/// string (or null when dismissed).
class QualityPickerSheet extends StatelessWidget {
  final List<String> qualities;

  const QualityPickerSheet({super.key, required this.qualities});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SELECT QUALITY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose the quality you want to download.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
            ),
            const SizedBox(height: 14),
            for (final quality in qualities) ...[
              GestureDetector(
                onTap: () => Navigator.pop(context, quality),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(color: Colors.white10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        quality.contains('1080') ? Icons.hd : Icons.high_quality,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        quality.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.download, color: Colors.white38, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}