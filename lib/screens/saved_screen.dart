import 'package:flutter/material.dart';
import 'package:tulabe/controllers/favorites_store.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/my_widgets/responsive_grid.dart';
import 'package:tulabe/screens/movie_detail_screen.dart';
import 'package:tulabe/screens/series_detail_screen.dart';
import '../theme/app_colors.dart';

/// Saved (favorites) screen — mirrors the web /saved page.
/// Tabs (All / Movies / Series), grid of saved cards with remove + Clear All.
/// Wired to the on-device [FavoritesStore] (persisted via shared_preferences).
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  FavoritesStore get _store => FavoritesStore.instance;
  int _tab = 0; // 0 all, 1 movies, 2 series

  List<FavoriteEntry> get _filtered {
    if (_tab == 0) return _store.items;
    return _store.items.where((e) => e.isSeries == (_tab == 2)).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
  }

  Movie _movieOf(FavoriteEntry e) {
    return Movie(
      id: e.id,
      title: e.title,
      imageUrl: e.thumbnailUrl,
      subtitle: e.releaseYear > 0 ? '${e.releaseYear}' : null,
    );
  }

  void _confirmClearAll() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Clear all saved?',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        content: const Text(
          'This removes every saved movie and series from this device.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _store.clear();
            },
            child: const Text('CLEAR ALL', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0118),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final items = _filtered;
            final isEmpty = _store.items.isEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header + Clear All
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
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
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'SAVED',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1),
                        ),
                      ),
                      if (!isEmpty)
                        GestureDetector(
                          onTap: _confirmClearAll,
                          child: const Text(
                            'CLEAR ALL',
                            style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _TabButton(label: 'ALL', active: _tab == 0, onTap: () => setState(() => _tab = 0)),
                      const SizedBox(width: 8),
                      _TabButton(label: 'MOVIES', active: _tab == 1, onTap: () => setState(() => _tab = 1)),
                      const SizedBox(width: 8),
                      _TabButton(label: 'SERIES', active: _tab == 2, onTap: () => setState(() => _tab = 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Grid / empty
                Expanded(
                  child: items.isEmpty
                      ? _EmptyState(
                          isEmpty: isEmpty,
                          onBrowse: () => Navigator.pop(context),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: movieColumns(context),
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            mainAxisExtent: movieCardExtent(context),
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final entry = items[index];
                            final movie = _movieOf(entry);
                            return _FavoriteCard(
                              entry: entry,
                              isSeries: entry.isSeries,
                              onRemove: () => _store.remove(entry.id, entry.type),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => entry.isSeries
                                      ? SeriesDetailScreen(series: movie)
                                      : MovieDetailScreen(movie: movie),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          border: Border.all(color: active ? AppColors.primary : Colors.white12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final FavoriteEntry entry;
  final bool isSeries;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  const _FavoriteCard({
    required this.entry,
    required this.isSeries,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final year = entry.releaseYear > 0 ? '${entry.releaseYear}'.replaceAll('-', '') : '';
    return Stack(
      children: [
        GestureDetector(
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
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (entry.thumbnailUrl.isNotEmpty)
                          Image.network(
                            entry.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppColors.cardBg,
                              child: Icon(isSeries ? Icons.tv : Icons.movie, color: AppColors.textTertiary, size: 30),
                            ),
                          )
                        else
                          Container(
                            color: AppColors.cardBg,
                            child: Icon(isSeries ? Icons.tv : Icons.movie, color: AppColors.textTertiary, size: 30),
                          ),
                        Positioned(
                          top: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2)),
                            child: Text(
                              isSeries ? 'SERIES' : 'MOVIE',
                              style: const TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.w700, letterSpacing: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, height: 1.3),
              ),
              const SizedBox(height: 2),
              Text(
                year,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
              ),
            ],
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isEmpty;
  final VoidCallback onBrowse;
  const _EmptyState({required this.isEmpty, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bookmark_border, color: Colors.white24, size: 40),
          const SizedBox(height: 10),
          Text(
            isEmpty ? 'Nothing saved yet.' : 'No movies or series saved.',
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap the + button on any movie or series to add it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onBrowse,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
              child: const Text(
                'BROWSE MOVIES',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}