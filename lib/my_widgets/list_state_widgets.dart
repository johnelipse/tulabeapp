import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Bottom footer for infinite-scroll grids: spinner while the next page is
/// loading, an "all loaded" label when there are no more pages.
class ListFooter extends StatelessWidget {
  final bool loadingMore;
  final bool hasMore;
  final String doneLabel;

  const ListFooter({
    super.key,
    required this.loadingMore,
    required this.hasMore,
    required this.doneLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            doneLabel,
            style: TextStyle(
              color: AppColors.textTertiary.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: 20);
  }
}

/// Full-area error state with a retry button shown when the first page fails.
class ListErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ListErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'RETRY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-area empty state with an optional "clear filters" action.
class ListEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool hasFilters;
  final VoidCallback onClear;

  const ListEmptyState({
    super.key,
    required this.icon,
    required this.message,
    required this.hasFilters,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onClear,
              child: const Text(
                'Clear filters',
                style: TextStyle(color: AppColors.primary, fontSize: 12, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ],
      ),
    );
  }
}