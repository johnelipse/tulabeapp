import 'package:flutter/material.dart';
import 'package:tulabe/models/movies.dart' hide Playlist;
import 'package:tulabe/models/playlist.dart';
import 'package:tulabe/my_widgets/list_state_widgets.dart';
import 'package:tulabe/my_widgets/responsive_grid.dart';
import 'package:tulabe/screens/movie_detail_screen.dart';
import 'package:tulabe/screens/series_detail_screen.dart';
import 'package:tulabe/services/api_client.dart';
import '../theme/app_colors.dart';

/// A single playlist's detail — mirrors the web /playlists/[id].
/// Header renders from the [Playlist] passed in (the list response), then
/// the item grid hydrates from `GET /api/playlists/:id`. Mutations (like /
/// rename / delete) hit the API and require ownership, so they're shown only
/// when the response reports `is_owner`.
class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final ApiClient _api = ApiClient();

  Playlist? _cache; // refreshed by GET /playlists/:id
  List<PlaylistItem> _items = const [];
  bool _liked = false;
  int _likeCount = 0;
  bool _isOwner = false;

  bool _loading = true;
  String? _error;

  bool _editingTitle = false;
  late String _titleDraft = widget.playlist.title;

  Playlist get _playlist => _cache ?? widget.playlist;
  int get _itemCount => _items.isEmpty ? _playlist.itemCount : _items.length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.dio.get('/playlists/${widget.playlist.id}');
      if (!mounted) return;
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          final rawPlaylist = data['playlist'];
          if (rawPlaylist is Map<String, dynamic>) {
            _cache = Playlist.fromJson(rawPlaylist);
          }
          final rawItems = data['items'];
          if (rawItems is List) _items = PlaylistItem.listFromJson(rawItems);
          _liked = data['liked'] as bool? ?? false;
          _isOwner = data['is_owner'] as bool? ?? false;
        }
      }
      setState(() {
        _likeCount = _playlist.likeCount;
        _titleDraft = _playlist.title;
      });
    } catch (e) {
      if (!mounted) return;
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  // Optimistic like toggle, rolled back on failure (mirrors web useToggle
  // PlaylistLike — the only realistic failure here is "not signed in").
  Future<void> _toggleLike() async {
    final wasLiked = _liked;
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    try {
      await _api.dio.post('/playlists/${widget.playlist.id}/like');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = wasLiked;
        _likeCount += _liked ? 1 : -1;
      });
    }
  }

  Future<void> _saveTitle() async {
    final t = _titleDraft.trim();
    if (t.isEmpty) return;
    setState(() => _editingTitle = false);
    try {
      await _api.dio.patch('/playlists/${widget.playlist.id}', data: {'title': t});
      if (!mounted) return;
      setState(() => _cache = _copyWith(_playlist, title: t));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to rename playlist')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete playlist?',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This can\'t be undone.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.dio.delete('/playlists/${widget.playlist.id}');
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete playlist')),
        );
      }
    }
  }

  Playlist _copyWith(Playlist p, {String? title, bool? isPublic}) {
    return Playlist(
      id: p.id,
      ownerId: p.ownerId,
      ownerName: p.ownerName,
      ownerAvatarUrl: p.ownerAvatarUrl,
      title: title ?? p.title,
      isPublic: isPublic ?? p.isPublic,
      viewCount: p.viewCount,
      likeCount: p.likeCount,
      itemCount: p.itemCount,
      coverUrls: p.coverUrls,
      isLiked: p.isLiked,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    );
  }

  /// Owner-only Public/Private toggle (mirrors the web detail page's Globe/Lock
  /// button). Admins can also flip anyone's playlist via `PATCH`.
  Future<void> _toggleVisibility() async {
    final before = _playlist;
    final target = !before.isPublic;
    setState(() => _cache = _copyWith(before, isPublic: target));
    try {
      await _api.dio.patch('/playlists/${before.id}', data: {'is_public': target});
    } catch (_) {
      if (!mounted) return;
      setState(() => _cache = _copyWith(before, isPublic: before.isPublic));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to change visibility')),
      );
    }
  }

  Movie _toMovie(PlaylistItem item) {
    final genres = item.genreNames
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final vjs = item.vjNames
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final subtitle = [
      if (item.releaseYear > 0) '${item.releaseYear}',
      if (genres.isNotEmpty) genres.join(', '),
    ].join(' - ');
    return Movie(
      id: item.id,
      title: item.title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      imageUrl: item.thumbnailUrl,
      badge: vjs.isEmpty ? null : vjs.first,
    );
  }

  void _openItem(PlaylistItem item) {
    final movie = _toMovie(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => item.isMovie
            ? MovieDetailScreen(movie: movie)
            : SeriesDetailScreen(series: movie),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _playlist;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0118),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: back + actions (wrapping)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                            color: Colors.white.withValues(alpha: 0.03),
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white60, size: 18),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _PillButton(
                            icon: _liked ? Icons.bookmark : Icons.bookmark_border,
                            label: _fmt(_likeCount),
                            filled: _liked,
                            onTap: _toggleLike,
                          ),
                          const SizedBox(width: 8),
                          _ViewPill(count: _fmt(playlist.viewCount)),
                          const SizedBox(width: 8),
                          if (_isOwner) ...[
                            _PillButton(
                              icon: playlist.isPublic ? Icons.public : Icons.lock_outline,
                              label: playlist.isPublic ? 'PUBLIC' : 'PRIVATE',
                              filled: playlist.isPublic,
                              onTap: _toggleVisibility,
                            ),
                            const SizedBox(width: 8),
                            _IconButton(
                              icon: Icons.edit_outlined,
                              color: AppColors.textSecondary,
                              onTap: () => setState(() {
                                _editingTitle = true;
                                _titleDraft = playlist.title;
                              }),
                            ),
                            const SizedBox(width: 8),
                            _IconButton(
                              icon: Icons.delete_outline,
                              color: AppColors.textSecondary,
                              onTap: _confirmDelete,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_editingTitle) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            controller: TextEditingController(text: _titleDraft),
                            maxLength: 200,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                            cursorColor: AppColors.primary,
                            decoration: const InputDecoration(
                              counterText: '',
                              hintText: 'Playlist name',
                              isDense: true,
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                            ),
                            onChanged: (v) => _titleDraft = v,
                            onSubmitted: (_) => _saveTitle(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _IconButton(icon: Icons.check, color: AppColors.primary, onTap: _saveTitle),
                        const SizedBox(width: 8),
                        _IconButton(
                          icon: Icons.close,
                          color: AppColors.textSecondary,
                          onTap: () => setState(() => _editingTitle = false),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            playlist.title.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (_isOwner) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() {
                              _editingTitle = true;
                              _titleDraft = playlist.title;
                            }),
                            child: const Icon(Icons.edit_outlined, color: Colors.white30, size: 16),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (playlist.ownerName.isNotEmpty ? playlist.ownerName[0] : 'T').toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'By ${playlist.ownerName.isEmpty ? 'a Tulabe user' : playlist.ownerName} · $_itemCount Movie${_itemCount != 1 ? 's' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            // Items
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: ListErrorState(message: error, onRetry: _load),
      );
    }
    if (_items.isEmpty) {
      return const _EmptyList();
    }
    final items = _items;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: movieColumns(context),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: movieCardExtent(context),
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final it = items[index];
        return _PlaylistItemCard(
          movie: _toMovie(it),
          onTap: () => _openItem(it),
        );
      },
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _PillButton({required this.icon, required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.transparent,
          border: Border.all(color: filled ? AppColors.primary : Colors.white12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: filled ? Colors.white : Colors.white60, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewPill extends StatelessWidget {
  final String count;
  const _ViewPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: Colors.white38, size: 14),
          const SizedBox(width: 5),
          Text(count, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 14),
      ),
    );
  }
}

class _PlaylistItemCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback onTap;
  const _PlaylistItemCard({required this.movie, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  movie.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.cardBg,
                    child: const Icon(Icons.movie, color: AppColors.textTertiary, size: 32),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined, color: Colors.white24, size: 40),
          SizedBox(height: 10),
          Text('Nothing added yet.', style: TextStyle(color: Colors.white38, fontSize: 14)),
          SizedBox(height: 4),
          Text(
            'Tap the Playlist icon on any movie or series to add it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }
}