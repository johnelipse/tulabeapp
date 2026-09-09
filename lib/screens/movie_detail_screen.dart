import 'package:flutter/material.dart';
import 'package:tulabe/controllers/favorites_store.dart';
import 'package:tulabe/controllers/movie_detail_controller.dart';
import 'package:tulabe/controllers/playback_controller.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/my_widgets/comments_section.dart';
import 'package:tulabe/my_widgets/inline_player.dart';
import 'package:tulabe/my_widgets/movie_card.dart';
import 'package:tulabe/my_widgets/quality_picker_sheet.dart';
import 'package:tulabe/my_widgets/responsive_grid.dart';
import 'package:tulabe/my_widgets/save_to_playlist_sheet.dart';
import 'package:tulabe/services/download_quota_store.dart';
import 'package:tulabe/services/download_service.dart';
import '../theme/app_colors.dart';

/// A single movie's detail — mirrors the web /movie/[id]: hero image (or the
/// player entry), metadata, actions, cast, and "more like this". Wired to the
/// Go API via [MovieDetailController] (`/movies/:id` + `/movies/:id/similar`).
class MovieDetailScreen extends StatefulWidget {
  final Movie movie;

  /// When > 0, the inline player auto-plays and seeks to this position — the
  /// "Continue Watching" resume flow.
  final double resumeFrom;

  const MovieDetailScreen({super.key, required this.movie, this.resumeFrom = 0});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final MovieDetailController _controller = MovieDetailController();
  final GlobalKey<InlinePlayerState> _playerKey = GlobalKey<InlinePlayerState>();
  bool _showFullDescription = false;
  int _downloadsRemaining = DownloadQuotaStore.downloadLimit;

  FavoritesStore get _favorites => FavoritesStore.instance;

  @override
  void initState() {
    super.initState();
    _favorites.ensureLoaded();
    _loadRemainingDownloads();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.movie.id;
    if (id == null || id.isEmpty) return;
    await _controller.load(id);
    if (mounted) setState(() {});
  }

  void _startPlayer(StreamMovie movie) {
    if (movie.id.isEmpty) return;
    _playerKey.currentState?.start();
  }

  void _retry() {
    _load();
  }

  Future<void> _loadRemainingDownloads() async {
    final remaining = await DownloadQuotaStore.instance.remaining();
    if (mounted) setState(() => _downloadsRemaining = remaining);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// Movie "Download" flow: resolve the ready qualities (single one → straight
  /// to it; 2+ → picker), then quota gate + preflight + enqueue.
  Future<void> _handleDownload(StreamMovie movie) async {
    final id = movie.id;
    if (id.isEmpty) return;

    final playback = PlaybackController();
    String quality = '1080p';
    try {
      await playback.load(id);
      final qualities = playback.data?.qualities ?? const <StreamMovieQuality>[];
      if (qualities.isNotEmpty) {
        if (qualities.length == 1) {
          quality = qualities.first.quality;
        } else {
          if (!mounted) return;
          final picked = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => QualityPickerSheet(
              qualities: qualities.map((q) => q.quality).toList(growable: false),
            ),
          );
          if (picked == null) return;
          quality = picked;
        }
      }
    } catch (_) {
      // Fall back to the default quality; the server also picks one from the
      // 720p → 1080p → 360p preference chain when the param is unknown.
    } finally {
      playback.dispose();
    }

    final result = await DownloadService.instance.startMovie(
      movieId: id,
      title: movie.title,
      quality: quality,
    );
    if (!mounted) return;
    if (result.started) {
      setState(() => _downloadsRemaining = result.remaining);
      final reset = DownloadQuotaStore.downloadWindowMin;
      _toast(result.remaining > 0
          ? 'Download started! ${result.remaining} download${result.remaining == 1 ? '' : 's'} left · resets in ${reset}m.'
          : "You've used all your downloads. Resets in ${reset}m.");
    } else if (result.error != null) {
      _toast(result.error!);
    }
  }

  void _notAvailable(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label is not available in this version yet'),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _toggleFavorite(StreamMovie movie) {
    _favorites.toggle(
      id: movie.id,
      type: 'movie',
      title: movie.title,
      thumbnailUrl: movie.thumbnailUrl,
      releaseYear: movie.releaseYear,
    );
  }

  void _saveToPlaylist(StreamMovie movie) {
    showSaveToPlaylist(context, contentType: 'movie', contentId: movie.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: Listenable.merge([_controller, _favorites]),
        builder: (context, _) {
          final movie = _controller.movie;
          if (movie == null) {
            if (_controller.loading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            return _DetailError(
              message: _controller.error != null
                  ? 'Failed to load movie'
                  : 'Movie not found',
              onBack: () => Navigator.pop(context),
              onRetry: _retry,
            );
          }
          return _buildContent(movie);
        },
      ),
    );
  }

  Widget _buildContent(StreamMovie movie) {
    final duration = _formatDuration(movie.durationSeconds);
    final isSaved = _favorites.isFavorited(movie.id, 'movie');
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              InlinePlayer(
                key: _playerKey,
                movieId: movie.id,
                title: movie.title,
                thumbnailUrl: movie.thumbnailUrl,
                resumeFrom: widget.resumeFrom,
              ),
              // Back button
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Tulabe • Available
              Row(
                children: [
                  const Text(
                    'TULABE',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 2),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('•', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                  ),
                  Text(
                    movie.status == MovieStatus.ready ? 'AVAILABLE' : 'PROCESSING',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 1),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                movie.title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 10),
              // Meta row
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (movie.releaseYear > 0)
                    Text(
                      '${movie.releaseYear}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  if (duration.isNotEmpty)
                    Text(duration, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  if (movie.allow1080p) const _MetaBadge(text: 'HD'),
                  if (movie.viewCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          '${_formatCount(movie.viewCount)} views',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (movie.description.isNotEmpty) ...[
                Text(
                  _showFullDescription
                      ? movie.description
                      : (movie.description.length > 80
                          ? '${movie.description.substring(0, 80)}…'
                          : movie.description),
                  maxLines: _showFullDescription ? null : 2,
                  overflow: _showFullDescription ? null : TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                ),
                if (movie.description.length > 80) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => setState(() => _showFullDescription = !_showFullDescription),
                    child: Text(
                      _showFullDescription ? 'LESS' : 'MORE',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              // Action buttons Row 1
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'PLAY',
                      icon: Icons.play_arrow,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
onTap: () => _startPlayer(movie),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label: _downloadsRemaining < 3
                          ? 'DOWNLOAD ($_downloadsRemaining left)'
                          : 'DOWNLOAD',
                      icon: Icons.download,
                      isOutline: true,
                      onTap: () => _handleDownload(movie),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _OutlinedBorderedButton(
                label: 'TELEGRAM',
                onTap: () => _notAvailable('Telegram'),
              ),
              const SizedBox(height: 16),
              ..._infoRows(movie),
              const SizedBox(height: 16),
              if (_controller.cast.isNotEmpty) ..._castSection(movie.title),
              // Action row
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                    bottom: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    _IconAction(
                      icon: isSaved ? Icons.check : Icons.add,
                      label: 'Add to Favorites',
                      active: isSaved,
                      onTap: () => _toggleFavorite(movie),
                    ),
                    _IconAction(
                      icon: Icons.thumb_up_outlined,
                      label: 'Rate',
                      onTap: () => _showRating(),
                    ),
                    _IconAction(
                      icon: Icons.playlist_add,
                      label: 'Add to Playlist',
                      onTap: () => _saveToPlaylist(movie),
                    ),
                    _IconAction(
                      icon: Icons.send_outlined,
                      label: 'Share',
                      onTap: () => _notAvailable('Share'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_controller.related.isNotEmpty) ...[
                Text(
                  'MORE LIKE ${movie.title.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ]),
          ),
        ),
        // Related grid
        if (_controller.related.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: movieColumns(context),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: movieCardExtent(context),
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final related = Movie.fromStreamMovie(_controller.related[index]);
                  return MovieCard(
                    movie: related,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MovieDetailScreen(movie: related),
                      ),
                    ),
                  );
                },
                childCount: _controller.related.length,
              ),
            ),
          ),
        // Comments
        SliverToBoxAdapter(
          child: CommentsSection(contentType: 'movie', contentId: movie.id),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  List<Widget> _infoRows(StreamMovie movie) {
    return [
      if (movie.description.isNotEmpty)
        Text(
          movie.description,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
      if (movie.genres.isNotEmpty) ...[
        const SizedBox(height: 8),
        _InfoRow(label: 'Genre: ', value: movie.genres.join(', ')),
      ],
      if (movie.vjs.isNotEmpty) _InfoRow(label: 'VJ: ', value: movie.vjs.join(', ')),
      if (movie.languageTranslated.isNotEmpty)
        _InfoRow(label: 'Language: ', value: movie.languageTranslated),
    ];
  }

  List<Widget> _castSection(String movieTitle) {
    return [
      const Text(
        'CAST',
        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _controller.cast.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final c = _controller.cast[index];
            return SizedBox(
              width: 80,
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: c.photoUrl.isNotEmpty
                        ? Image.network(
                            c.photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.person, color: AppColors.textTertiary, size: 32),
                          )
                        : const Icon(Icons.person, color: AppColors.textTertiary, size: 32),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    c.characterName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  void _showRating() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _RatingSheet(),
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  static String _formatCount(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }
}

class _DetailError extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  const _DetailError({
    required this.message,
    required this.onBack,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 44, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'GO BACK',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'RETRY',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String text;
  const _MetaBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isOutline;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.isOutline = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isOutline ? Colors.transparent : (backgroundColor ?? AppColors.primary);
    final fg = isOutline ? Colors.white : (foregroundColor ?? Colors.white);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: isOutline ? Border.all(color: Colors.white24) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 17),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedBorderedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlinedBorderedButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12),
          children: [
            TextSpan(text: label, style: const TextStyle(color: AppColors.textSecondary)),
            TextSpan(text: value, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? AppColors.primary : AppColors.textSecondary, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? AppColors.primary : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingSheet extends StatefulWidget {
  const _RatingSheet();

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'RATE THIS MOVIE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a star to rate',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final n = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _selected = n),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.star,
                      size: 36,
                      color: n <= _selected ? Colors.amber : AppColors.border,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _selected > 0
                        ? () {
                            Navigator.pop(context);
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text(
                          'SUBMIT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}