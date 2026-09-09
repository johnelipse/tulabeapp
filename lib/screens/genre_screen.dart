import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tulabe/controllers/genre_movies_controller.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/my_widgets/list_state_widgets.dart';
import 'package:tulabe/my_widgets/movie_card.dart';
import 'package:tulabe/my_widgets/responsive_grid.dart';
import 'package:tulabe/screens/movie_detail_screen.dart';
import '../theme/app_colors.dart';

/// Genre page — mirrors the web /genre/[id]: a filtered grid of movies in a
/// given genre, with search + VJ filter. Wired to the Go API via
/// [GenreMoviesController] (`/movies?genre_id=&search=&vj_id=`).
class GenreScreen extends StatefulWidget {
  final String genre;
  final String? genreId;
  const GenreScreen({super.key, required this.genre, this.genreId});

  @override
  State<GenreScreen> createState() => _GenreScreenState();
}

class _GenreScreenState extends State<GenreScreen> {
  final GenreMoviesController _controller = GenreMoviesController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  String? _activeVJ;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _controller.loadFilterOptions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGenre());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _controller.loadMore();
    }
  }

  Future<void> _loadGenre() {
    return _controller.reload(
      genreName: widget.genre,
      genreId: widget.genreId,
      search: _search,
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _search = value);
      _controller.loadFirstPage(
        search: value,
        genreId: _controller.resolvedGenreId,
        vjId: _activeVJ,
      );
    });
  }

  void _selectVJ(String? id) {
    final next = (id == null || _activeVJ == id) ? null : id;
    setState(() => _activeVJ = next);
    _controller.loadFirstPage(
      search: _search,
      genreId: _controller.resolvedGenreId,
      vjId: next,
    );
  }

  void _clearFilters() {
    _debounce?.cancel();
    setState(() {
      _search = '';
      _activeVJ = null;
      _searchController.clear();
    });
    _controller.loadFirstPage(
      search: '',
      genreId: _controller.resolvedGenreId,
      vjId: null,
    );
  }

  bool get _hasFilters => _search.trim().isNotEmpty || _activeVJ != null;

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
          widget.genre.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search + filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      inputFormatters: [LengthLimitingTextInputFormatter(100)],
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        hintText: 'Search ${widget.genre.toLowerCase()} movies…',
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
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _openFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, color: Colors.white60, size: 14),
                        const SizedBox(width: 5),
                        const Text(
                          'FILTERS',
                          style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
                        ),
                        if (_activeVJ != null) ...[
                          const SizedBox(width: 5),
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
          // Grid / states
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final items = _controller.items;
        if (_controller.initialLoading && items.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (_controller.error != null && items.isEmpty) {
          return ListErrorState(
            message: 'Failed to load ${widget.genre.toLowerCase()} movies',
            onRetry: _loadGenre,
          );
        }
        if (items.isEmpty) {
          return ListEmptyState(
            icon: Icons.search_off,
            message: 'No movies found',
            hasFilters: _hasFilters,
            onClear: _clearFilters,
          );
        }
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: movieColumns(context),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: movieCardExtent(context),
          ),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == items.length) {
              return ListFooter(
                loadingMore: _controller.loadingMore,
                hasMore: _controller.hasMore,
                doneLabel: "YOU'RE ALL CAUGHT UP — ${widget.genre.toUpperCase()}",
              );
            }
            final movie = Movie.fromStreamMovie(items[index]);
            return MovieCard(
              movie: movie,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
              ),
            );
          },
        );
      },
    );
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (sheetContext) {
        final vjs = _controller.vjs.toList(growable: false);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FILTER ${widget.genre}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                    const SizedBox(height: 2),
                    const Text('Narrow down what you want to watch.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 20),
                    const Text('VJ', style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _activeVJ == null,
                          onTap: () {
                            setSheetState(() {});
                            _selectVJ(null);
                          },
                        ),
                        ...vjs.map((v) {
                          final id = '${v.id}';
                          return _FilterChip(
                            label: (v.name.isNotEmpty ? v.name.replaceFirst('VJ ', '') : 'UNKNOWN').toUpperCase(),
                            selected: _activeVJ == id,
                            onTap: () {
                              setSheetState(() {});
                              _selectVJ(id);
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetContext),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                        child: const Center(
                          child: Text('APPLY FILTERS',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: selected ? AppColors.primary : Colors.white12),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}