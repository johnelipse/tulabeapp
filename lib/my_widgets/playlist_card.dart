import 'package:flutter/material.dart';
import 'package:tulabe/models/playlist.dart';
import '../theme/app_colors.dart';

/// A playlist card — mirrors the web's PlaylistCard: a collage cover (one
/// featured thumbnail on the left + a 2x2 quad on the right, from the API's
/// `cover_urls`), title, and item count. API-driven; tap opens the detail.
class PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;

  const PlaylistCard({
    super.key,
    required this.playlist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Collage(playlist: playlist),
          const SizedBox(height: 7),
          Text(
            playlist.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${playlist.itemCount} Movie${playlist.itemCount != 1 ? 's' : ''}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// Collage cover: a tall featured cell (most-recently-added item) next to a
/// 2x2 quad of the next 4 thumbnails — mirrors the web's `PlaylistCollage`
/// (and the backend's coverURLsFor). Missing tiles fall back to the glyph.
class _Collage extends StatelessWidget {
  final Playlist playlist;
  const _Collage({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final urls = playlist.coverUrls.where((u) => u.isNotEmpty).toList();
    final featured = urls.isNotEmpty ? urls.first : null;

    // Next 4 after the featured one, padded with nulls to fill 4 slots.
    final quad = <String?>[
      if (urls.length > 1) ...urls.sublist(1, urls.length > 5 ? 5 : urls.length),
    ];
    while (quad.length < 4) {
      quad.add(null);
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(child: _cell(featured, large: true)),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _row(quad[0], quad[1])),
                    const SizedBox(height: 2),
                    Expanded(child: _row(quad[2], quad[3])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String? a, String? b) {
    return Row(
      children: [
        Expanded(child: _cell(a)),
        const SizedBox(width: 2),
        Expanded(child: _cell(b)),
      ],
    );
  }

  Widget _cell(String? url, {bool large = false}) {
    if (url == null) {
      return Container(
        color: AppColors.surface,
        child: Icon(
          Icons.video_library_outlined,
          color: AppColors.textTertiary,
          size: large ? 22 : 12,
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => Container(
        color: AppColors.surface,
        child: Icon(
          Icons.movie,
          color: AppColors.textTertiary,
          size: large ? 24 : 12,
        ),
      ),
    );
  }
}