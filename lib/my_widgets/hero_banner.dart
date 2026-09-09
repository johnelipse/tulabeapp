import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tulabe/models/movies.dart';

import '../theme/app_colors.dart';

/// Auto-scrolling hero carousel showing the top latest movies.
class HeroBanner extends StatefulWidget {
  final List<HeroItem> movies;
  final VoidCallback? onWatchNow;
  final VoidCallback? onLatestMovies;

  const HeroBanner({
    super.key,
    required this.movies,
    this.onWatchNow,
    this.onLatestMovies,
  });

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    if (widget.movies.length < 2) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() => _current = (_current + 1) % widget.movies.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 900),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: _HeroPage(
              key: ValueKey(_current),
              movie: widget.movies[_current],
              onWatchNow: widget.onWatchNow,
              onLatestMovies: widget.onLatestMovies,
            ),
          ),
          if (widget.movies.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.movies.length, (i) {
                  final active = i == _current;
                  return GestureDetector(
                    onTap: () => setState(() => _current = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroPage extends StatelessWidget {
  final HeroItem movie;
  final VoidCallback? onWatchNow;
  final VoidCallback? onLatestMovies;

  const _HeroPage({
    super.key,
    required this.movie,
    this.onWatchNow,
    this.onLatestMovies,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          movie.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: AppColors.surface),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.heroGradientStart,
                AppColors.heroGradientMid,
                AppColors.heroGradientEnd,
              ],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.overlayDark,
                Colors.transparent,
                Colors.transparent,
              ],
              stops: [0.0, 0.4, 1.0],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                movie.vjNames.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie.title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                movie.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MetaBadge(text: movie.releaseYear > 0 ? '${movie.releaseYear}' : ''),
                  const SizedBox(width: 10),
                  Text(
                    movie.genreNames,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.access_time,
                    size: 12,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    movie.durationSeconds > 0 ? '${movie.durationSeconds ~/ 60} min' : '',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ActionButton(
                    label: 'WATCH NOW',
                    icon: Icons.play_arrow,
                    isPrimary: true,
                    onPressed: onWatchNow,
                  ),
                  const SizedBox(width: 12),
                  _ActionButton(
                    label: 'LATEST MOVIES',
                    isPrimary: false,
                    onPressed: onLatestMovies,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String text;
  const _MetaBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    this.icon,
    required this.isPrimary,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(3),
          border: isPrimary ? null : Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
