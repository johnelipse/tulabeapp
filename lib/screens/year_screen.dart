import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tulabe/controllers/year_movies_controller.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/my_widgets/list_state_widgets.dart';
import 'package:tulabe/my_widgets/movie_card.dart';
import 'package:tulabe/my_widgets/responsive_grid.dart';
import 'package:tulabe/screens/movie_detail_screen.dart';
import '../theme/app_colors.dart';

/// Browse all movies from one release year — mirrors the web's "Browse by
/// Year" chips, which deep-link to `/movies?year=X`. Wired to the Go API via
/// [YearMoviesController] (infinite scroll + optional server-side search).
class YearScreen extends StatefulWidget {
  final int year;
  const YearScreen({super.key, required this.year});

  @override
  State<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends State<YearScreen> {
  final YearMoviesController _controller = YearMoviesController();
  final ScrollController _scrollController = ScrollController();

  String _search = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (_search == value) return;
      _search = value;
      _reload();
    });
  }

  Future<void> _reload() async {
    await _controller.reload(year: '${widget.year}', search: _search);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _clearSearch() {
    _search = '';
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0118),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0118),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white60),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.year} MOVIES',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              height: 38,
              child: TextField(
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: 'Search ${widget.year} movies…',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: Colors.white30, size: 16),
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
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
                    message: 'No movies from ${widget.year}',
                    hasFilters: _search.trim().isNotEmpty,
                    onClear: _clearSearch,
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
                        doneLabel: 'END OF RESULTS',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}