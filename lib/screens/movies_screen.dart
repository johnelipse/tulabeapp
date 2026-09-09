import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tulabe/controllers/movies_controller.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/my_widgets/filters_sheet.dart';
import 'package:tulabe/my_widgets/list_state_widgets.dart';
import 'package:tulabe/my_widgets/movie_card.dart';
import 'package:tulabe/my_widgets/responsive_grid.dart';
import 'package:tulabe/screens/movie_detail_screen.dart';
import '../theme/app_colors.dart';

/// Movies browse tab — infinite-scroll grid of all movies with search +
/// filters, mirroring the web /movies page (`useInfiniteMovies`, limit 20).
class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  final MoviesController _controller = MoviesController();
  final ScrollController _scrollController = ScrollController();

  String _search = '';
  String _genre = '';
  String _vj = '';
  String _year = '';
  bool _latestOnly = false;

  Timer? _debounce;
  bool _filtersChanged = false;

  bool get _hasFilters => _genre.isNotEmpty || _vj.isNotEmpty || _latestOnly || _year.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _controller.loadFilterOptions();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _controller.loadMore();
    }
  }

  String? get _genreId {
    for (final g in _controller.genres) {
      if (g.name == _genre) return '${g.id}';
    }
    return null;
  }

  String? get _vjId {
    for (final v in _controller.vjs) {
      if (v.name == _vj) return '${v.id}';
    }
    return null;
  }

  Future<void> _reload() async {
    await _controller.reload(
      search: _search,
      genreId: _genreId,
      vjId: _vjId,
      latest: _latestOnly,
      year: _year,
    );
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (_search == value) return;
      _search = value;
      _reload();
    });
  }

  Future<void> _openFilters() async {
    _filtersChanged = false;
    final genreLabels = _controller.genres
        .where((g) => g.isActive)
        .map((g) => g.name)
        .toList();
    final vjLabels = _controller.vjs.map((v) => v.name).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FiltersSheet(
        showLatest: true,
        latestOnly: _latestOnly,
        activeGenre: _genre,
        activeVJ: _vj,
        activeYear: _year,
        genreLabels: genreLabels,
        vjLabels: vjLabels,
        onLatestChanged: (v) {
          _latestOnly = v;
          _filtersChanged = true;
        },
        onGenreChanged: (v) {
          _genre = v;
          _filtersChanged = true;
        },
        onVJChanged: (v) {
          _vj = v;
          _filtersChanged = true;
        },
        onYearChanged: (v) {
          _year = v;
          _filtersChanged = true;
        },
      ),
    );

    if (_filtersChanged) {
      _reload();
    }
  }

  void _clearFilters() {
    setState(() {
      _genre = '';
      _vj = '';
      _year = '';
      _latestOnly = false;
      _search = '';
    });
    _debounce?.cancel();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search + Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Search movies…',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      prefixIcon: Icon(Icons.search, color: AppColors.textTertiary, size: 16),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _openFilters,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: _hasFilters ? AppColors.primary.withValues(alpha: 0.1) : AppColors.cardBg,
                    border: Border.all(color: _hasFilters ? AppColors.primary : AppColors.border),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, size: 14, color: _hasFilters ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'FILTERS',
                        style: TextStyle(
                          color: _hasFilters ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      if (_hasFilters) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Infinite-scroll grid
        Expanded(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.initialLoading && _controller.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_controller.error != null && _controller.items.isEmpty) {
                return ListErrorState(
                  message: 'Failed to load movies',
                  onRetry: _reload,
                );
              }

              final movies = _controller.items
                  .map(Movie.fromStreamMovie)
                  .toList(growable: false);

              if (movies.isEmpty) {
                return ListEmptyState(
                  icon: Icons.movie_outlined,
                  message: 'No movies found',
                  hasFilters: _hasFilters,
                  onClear: _clearFilters,
                );
              }

              return CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
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
                        (context, index) => MovieCard(
                          movie: movies[index],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MovieDetailScreen(movie: movies[index]),
                            ),
                          ),
                        ),
                        childCount: movies.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ListFooter(
                      loadingMore: _controller.loadingMore,
                      hasMore: _controller.hasMore,
                      doneLabel: 'ALL MOVIES LOADED',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}