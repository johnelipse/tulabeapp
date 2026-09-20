import 'package:flutter/material.dart';
import 'package:tulabe/controllers/favorites_store.dart';
import 'package:tulabe/controllers/series_detail_controller.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/my_widgets/comments_section.dart';
import 'package:tulabe/my_widgets/inline_player.dart';
import 'package:tulabe/my_widgets/movie_card.dart';
import 'package:tulabe/my_widgets/responsive_grid.dart';
import 'package:tulabe/my_widgets/save_to_playlist_sheet.dart';
import 'package:tulabe/services/download_service.dart';
import '../theme/app_colors.dart';

/// A single series' detail — mirrors the web /series/[id]: banner with the
/// player entry point, metadata, real seasons/episodes, cast, and "more like
/// this". Wired to the Go API via [SeriesDetailController]
/// (`/series/:id` + `/series/:id/similar`). Episodes play through their
/// `stream_movie_id` (the underlying movie), matching the web player.
class SeriesDetailScreen extends StatefulWidget {
  final Movie series;

  /// "Continue Watching" resume: the episode (`stream_movie_id`) to auto-play
  /// once the series loads, and the position (seconds) to seek to.
  final String? initialEpisodeMovieId;
  final double resumeFrom;

  const SeriesDetailScreen({
    super.key,
    required this.series,
    this.initialEpisodeMovieId,
    this.resumeFrom = 0,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  final SeriesDetailController _controller = SeriesDetailController();

  int _selectedSeason = 1;
  String? _activeEpisodeId;
  final GlobalKey<InlinePlayerState> _playerKey = GlobalKey<InlinePlayerState>();

  FavoritesStore get _favorites => FavoritesStore.instance;

  @override
  void initState() {
    super.initState();
    _favorites.ensureLoaded();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.series.id;
    if (id == null || id.isEmpty) return;
    final previous = _controller.series?.id;
    await _controller.load(id);
    if (!mounted) return;
    // Reset the season selector when a new series loads.
    if (id != '$previous') {
      _autoResumeEpisode();
    } else {
      setState(() {});
    }
  }

  /// Picks the initial state on load: if the screen was opened to resume an
  /// episode ("Continue Watching"), select that episode's season, highlight
  /// it, and auto-start the player; otherwise reset to season 1 with nothing
  /// selected.
  void _autoResumeEpisode() {
    final initial = widget.initialEpisodeMovieId;
    if (initial == null || initial.isEmpty) {
      setState(() {
        _selectedSeason = 1;
        _activeEpisodeId = null;
      });
      return;
    }
    final season = _controller.seasons
        .where((s) => s.episodes.any((e) => e.streamMovieId == initial))
        .firstOrNull;
    final match = _controller.allEpisodes
        .where((e) => e.streamMovieId == initial)
        .firstOrNull;
    if (match == null) {
      setState(() {
        _selectedSeason = 1;
        _activeEpisodeId = null;
      });
      return;
    }
    setState(() {
      _selectedSeason = season?.season ?? 1;
      _activeEpisodeId = initial;
    });
    // The inline player mounts on the next frame (it only exists once an
    // episode is selected), so reach it after the rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playerKey.currentState?.start();
    });
  }

  void _retry() => _load();

  void _playEpisode(Episode ep, Series series) {
    if (ep.streamMovieId.isEmpty) return;
    setState(() => _activeEpisodeId = ep.streamMovieId);
    // The inline player first mounts on the next frame (it only exists once
    // an episode is selected), so reach it after the rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playerKey.currentState?.start();
    });
  }

  void _play(Episode ep, Series series) => _playEpisode(ep, series);

  /// When the current episode finishes, start the next one (across seasons),
  /// matching the web player's mobile UX. Only fires automatically between
  /// episodes of the same series.
  void _onEpisodeFinished() {
    final all = _controller.allEpisodes;
    if (_activeEpisodeId == null || all.isEmpty) return;
    final index = all.indexWhere((e) => e.streamMovieId == _activeEpisodeId);
    if (index < 0 || index + 1 >= all.length) return;
    final next = all[index + 1];
    if (next.streamMovieId.isEmpty) return;
    // The player widget swaps to the next episode's source; the player is
    // already mounted, so start it on the next frame.
    setState(() => _activeEpisodeId = next.streamMovieId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playerKey.currentState?.start();
    });
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

  /// Per-episode download: one quality, no picker (mirrors the web series
  /// page). Shared client quota + preflight + DownloadManager enqueue.
  Future<void> _downloadEpisode(Episode ep, Series series) async {
    if (ep.streamMovieId.isEmpty) return;
    final result = await DownloadService.instance.startEpisode(
      movieId: ep.streamMovieId,
      title: '${series.title} S${ep.seasonNumber}E${ep.episodeNumber}',
      episodeNumber: ep.episodeNumber,
    );
    if (!mounted) return;
    if (result.started) {
      _toast('Downloading "${ep.title}"… ${result.remaining} '
          'download${result.remaining == 1 ? '' : 's'} left this window.');
    } else if (result.error != null) {
      _toast(result.error!);
    }
  }

  void _toggleFavorite(Series series) {
    _favorites.toggle(
      id: '${series.id}',
      type: 'series',
      title: series.title,
      thumbnailUrl: series.posterUrl.isNotEmpty ? series.posterUrl : series.bannerUrl,
      releaseYear: series.releaseYear,
    );
  }

  void _saveToPlaylist(Series series) {
    showSaveToPlaylist(context, contentType: 'series', contentId: '${series.id}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: Listenable.merge([_controller, _favorites]),
        builder: (context, _) {
          final series = _controller.series;
          if (series == null) {
            if (_controller.loading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            return _SeriesError(
              message: _controller.error != null
                  ? 'Failed to load series'
                  : 'Series not found',
              onBack: () => Navigator.pop(context),
              onRetry: _retry,
            );
          }
          return _buildContent(series);
        },
      ),
    );
  }

  Widget _buildContent(Series series) {
    final seasons = _controller.seasons;
    final episodes = seasons
        .where((s) => s.season == _selectedSeason)
        .fold<List<Episode>>(<Episode>[], (acc, s) => acc..addAll(s.episodes));
    final allEpisodes = _controller.allEpisodes;
    final firstPlayable = allEpisodes.where((e) => e.streamMovieId.isNotEmpty).firstOrNull;
    final activeEpisode = allEpisodes
        .where((e) => e.streamMovieId == _activeEpisodeId)
        .firstOrNull;
    final isSaved = _favorites.isFavorited('${series.id}', 'series');
    final banner = series.posterUrl.isNotEmpty ? series.posterUrl : series.bannerUrl;

    return CustomScrollView(
      slivers: [
        // Banner
        SliverToBoxAdapter(
          child: Stack(
            children: [
              if (activeEpisode != null && activeEpisode.streamMovieId.isNotEmpty)
                InlinePlayer(
                  key: _playerKey,
                  movieId: activeEpisode.streamMovieId,
                  title: '${series.title} · Ep ${activeEpisode.episodeNumber}',
                  thumbnailUrl: banner,
                  resumeFrom: widget.resumeFrom,
                  seriesId: '${series.id}',
                  onFinished: _onEpisodeFinished,
                )
              else
                _posterBanner(banner, firstPlayable, series),
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
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
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
              // Series • Tulabe • status
              Row(
                children: [
                  const Text(
                    'SERIES',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 2),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('•', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                  ),
                  const Text(
                    'TULABE',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 2),
                  ),
                  if (series.status.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('•', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                    ),
                    Text(
                      series.status.toUpperCase(),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 1),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                series.title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  height: 1.05,
                ),
              ),
              if (activeEpisode != null) ...[
                const SizedBox(height: 6),
                Text(
                  'NOW PLAYING: Ep ${activeEpisode.episodeNumber} — ${activeEpisode.title}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              // Meta
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (series.releaseYear > 0)
                    Text('${series.releaseYear}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  if (seasons.isNotEmpty)
                    Text(
                      '${seasons.length} Season${seasons.length != 1 ? 's' : ''}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  if (allEpisodes.isNotEmpty)
                    Text(
                      '${allEpisodes.length} Episodes',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  if (series.viewCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          '${_formatCount(series.viewCount)} views',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (series.description.isNotEmpty)
                Text(
                  series.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
              if (series.genreNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(label: 'Genre: ', value: _splitComma(series.genreNames).join(', ')),
              ],
              if (series.vjNames.isNotEmpty) _InfoRow(label: 'VJ: ', value: _splitComma(series.vjNames).join(', ')),
              const SizedBox(height: 16),
              // Play button
              if (firstPlayable != null)
                _ActionButton(
                  label: 'PLAY S${firstPlayable.seasonNumber}E${firstPlayable.episodeNumber}',
                  icon: Icons.play_arrow,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  onTap: () => _play(firstPlayable, series),
                )
              else
                _ActionButton(
                  label: 'NO PLAYABLE EPISODES',
                  icon: Icons.play_arrow,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  onTap: () => _notAvailable('Playback'),
                ),
              const SizedBox(height: 8),
              _OutlinedButton(
                label: 'JOIN TELEGRAM',
                iconColor: AppColors.primary,
                onTap: () => _notAvailable('Telegram'),
              ),
              const SizedBox(height: 16),
              // Icon row
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
                      onTap: () => _toggleFavorite(series),
                    ),
                    _IconAction(
                      icon: Icons.thumb_up_outlined,
                      label: 'Rate',
                      onTap: () => _showRating(),
                    ),
                    _IconAction(
                      icon: Icons.playlist_add,
                      label: 'Add to Playlist',
                      onTap: () => _saveToPlaylist(series),
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
            ]),
          ),
        ),
        // Episodes section
        if (seasons.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'EPISODES',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${episodes.length})',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                  const Spacer(),
                  if (seasons.length > 1)
                    _SeasonDropdown(
                      selectedSeason: _selectedSeason,
                      seasons: seasons.map((s) => s.season).toList(),
                      onChanged: (s) => setState(() => _selectedSeason = s),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final ep = episodes[index];
                  return _EpisodeRow(
                    episode: ep,
                    imageUrl: banner,
                    seriesDescription: series.description,
                    active: _activeEpisodeId != null && ep.streamMovieId == _activeEpisodeId,
                    onPlay: ep.streamMovieId.isNotEmpty ? () => _play(ep, series) : null,
                    onDownload: ep.streamMovieId.isNotEmpty ? () => _downloadEpisode(ep, series) : null,
                  );
                },
                childCount: episodes.length,
              ),
            ),
          ),
          if (episodes.isEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            const SliverToBoxAdapter(
              child: Center(
                child: Text(
                  'No episodes available yet for this season.',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
        // Cast
        if (_controller.cast.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            sliver: SliverToBoxAdapter(child: _CastSection(cast: _controller.cast)),
          ),
        // More like this
        if (_controller.related.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MORE LIKE ${series.title.toUpperCase()}',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                  final related = Movie.fromSeries(_controller.related[index]);
                  return MovieCard(
                    movie: related,
                    isSeries: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SeriesDetailScreen(series: related),
                      ),
                    ),
                  );
                },
                childCount: _controller.related.length,
              ),
            ),
          ),
        ],
        // Comments
        SliverToBoxAdapter(
          child: CommentsSection(contentType: 'series', contentId: '${series.id}'),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  /// The 16:9 banner shown before an episode is selected: poster + the same
  /// gradient mask + center play button treatment as the web series banner.
  Widget _posterBanner(String image, Episode? playable, Series series) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: AppColors.surface,
            child: Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: AppColors.surface),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black, Colors.transparent, Colors.transparent],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black54, Colors.transparent, Colors.black54],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: playable != null ? () => _play(playable, series) : null,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30),
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
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

  static List<String> _splitComma(String value) {
    if (value.isEmpty) return const <String>[];
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _SeriesError extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  const _SeriesError({required this.message, required this.onBack, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tv_off, size: 44, color: AppColors.textTertiary),
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

class _EpisodeRow extends StatelessWidget {
  final Episode episode;
  final String imageUrl;
  final String seriesDescription;
  final bool active;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;

  const _EpisodeRow({
    required this.episode,
    required this.imageUrl,
    required this.seriesDescription,
    required this.active,
    required this.onPlay,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final playable = onPlay != null;
    return GestureDetector(
      onTap: playable ? onPlay : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? Colors.redAccent.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(color: active ? Colors.redAccent.withValues(alpha: 0.3) : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Thumbnail (16:9)
            Container(
              width: 104,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(imageUrl, fit: BoxFit.cover),
                    if (active)
                      Container(color: Colors.black.withValues(alpha: 0.3), alignment: Alignment.center, child: _NowPlayingBars())
                    else
                      Container(
                        alignment: Alignment.center,
                        child: _PlayCircle(),
                      ),
                    if (episode.partNumber > 1)
                      Positioned(
                        top: 3,
                        left: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Pt ${episode.partNumber}',
                            style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    if (episode.durationSeconds > 0)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            _formatDuration(episode.durationSeconds),
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${episode.episodeNumber}. ${episode.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? Colors.redAccent : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (episode.durationSeconds > 0) ...[
                        const Icon(Icons.access_time, size: 10, color: AppColors.textTertiary),
                        const SizedBox(width: 3),
                        Text(
                          _formatDuration(episode.durationSeconds),
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                        ),
                      ],
                      if (!playable) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Processing…',
                          style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w500),
                        ),
                      ],
                      if (active) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'NOW PLAYING',
                          style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                  if (seriesDescription.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      seriesDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            if (onDownload != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDownload,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Icon(
                    Icons.download,
                    size: 14,
                    color: active ? Colors.redAccent : AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

class _NowPlayingBars extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(0.6), _bar(0.8), _bar(0.5),
      ],
    );
  }

  Widget _bar(double h) => Container(
        width: 3,
        height: 12 * h,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(2)),
      );
}

class _PlayCircle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white60),
        color: Colors.black.withValues(alpha: 0.4),
      ),
      child: const Icon(Icons.play_arrow, color: Colors.white, size: 13),
    );
  }
}

class _SeasonDropdown extends StatelessWidget {
  final int selectedSeason;
  final List<int> seasons;
  final ValueChanged<int> onChanged;
  const _SeasonDropdown({
    required this.selectedSeason,
    required this.seasons,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              'Season $selectedSeason',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in seasons)
              GestureDetector(
                onTap: () {
                  onChanged(s);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  color: s == selectedSeason ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
                  child: Text(
                    'Season $s',
                    style: TextStyle(
                      color: s == selectedSeason ? Colors.redAccent : Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    this.backgroundColor,
    this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        width: double.infinity,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.primary,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foregroundColor ?? Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: foregroundColor ?? Colors.white,
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

class _OutlinedButton extends StatelessWidget {
  final String label;
  final Color iconColor;
  final VoidCallback onTap;
  const _OutlinedButton({required this.label, required this.iconColor, required this.onTap});

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
            Icon(Icons.send, color: iconColor, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: iconColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
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
  const _IconAction({required this.icon, required this.label, this.active = false, required this.onTap});

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

class _CastSection extends StatelessWidget {
  final List<CastMember> cast;
  const _CastSection({required this.cast});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'CAST',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cast.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final c = cast[index];
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
        const SizedBox(height: 8),
      ],
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
            const Text('RATE THIS SERIES',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 4),
            const Text('Tap a star to rate', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final n = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _selected = n),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.star, size: 36, color: n <= _selected ? Colors.amber : AppColors.border),
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
                        child: Text('CANCEL',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _selected > 0 ? () => Navigator.pop(context) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                      child: const Center(
                        child: Text('SUBMIT',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
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