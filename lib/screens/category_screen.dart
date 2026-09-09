import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tulabe/controllers/movies_controller.dart';
import 'package:tulabe/controllers/series_controller.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/my_widgets/list_state_widgets.dart';
import 'package:tulabe/my_widgets/movie_card.dart';
import 'package:tulabe/my_widgets/responsive_grid.dart';
import 'package:tulabe/screens/movie_detail_screen.dart';
import 'package:tulabe/screens/series_detail_screen.dart';
import '../theme/app_colors.dart';

/// Category page — mirrors the web /category/[id] (movies / series / latest).
/// Wired to the Go API: `latest` → `/movies?latest=true`, `movies` → `/movies`,
/// `series` → `/series` (each with infinite scroll + debounced search).
class CategoryScreen extends StatefulWidget {
  final String categoryId;
  const CategoryScreen({super.key, required this.categoryId});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final MoviesController _moviesController = MoviesController();
  final SeriesController _seriesController = SeriesController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _tab = 0; // 0 movies, 1 series
  String _search = '';

  String get _categoryId => widget.categoryId;

  String get _title {
    switch (_categoryId) {
      case 'series':
        return 'SERIES';
      case 'latest':
        return 'LATEST MOVIES';
      case 'movies':
        return 'ALL MOVIES';
      default:
        return _categoryId.toUpperCase();
    }
  }

  bool get _isSeriesCategory => _categoryId == 'series';
  bool get _usingSeries => _isSeriesCategory || _tab == 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadActive());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _moviesController.dispose();
    _seriesController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_usingSeries) {
      _seriesController.loadMore();
    } else {
      _moviesController.loadMore();
    }
  }

  bool get _initialLoading =>
      _usingSeries ? _seriesController.initialLoading : _moviesController.initialLoading;
  bool get _loadingMore =>
      _usingSeries ? _seriesController.loadingMore : _moviesController.loadingMore;
  bool get _hasMore => _usingSeries ? _seriesController.hasMore : _moviesController.hasMore;
  String? get _error => _usingSeries ? _seriesController.error : _moviesController.error;

  Future<void> _reloadActive({String search = ''}) {
    if (_usingSeries) return _seriesController.reload(search: search);
    return _moviesController.reload(search: search, latest: _categoryId == 'latest');
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _search = value);
      _reloadActive(search: value);
    });
  }

  void _selectTab(int tab) {
    setState(() => _tab = tab);
    if (_usingSeries) {
      if (_seriesController.items.isEmpty &&
          !_seriesController.initialLoading &&
          _seriesController.error == null) {
        _reloadActive(search: _search);
      }
    } else if (_moviesController.items.isEmpty &&
        !_moviesController.initialLoading &&
        _moviesController.error == null) {
      _reloadActive(search: _search);
    }
  }

  List<Movie> get _items {
    if (_usingSeries) {
      return (List<Object>.from(_seriesController.items))
          .map((s) => Movie.fromSeries(s as Series))
          .toList(growable: false);
    }
    return (List<Object>.from(_moviesController.items))
        .map((m) => Movie.fromStreamMovie(m as StreamMovie))
        .toList(growable: false);
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
          _title,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                style: const TextStyle(color: Colors.white, fontSize: 12),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: _isSeriesCategory ? 'Search series…' : 'Search movies…',
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
          // Category tabs (series shows only series; movies/latest can toggle)
          if (!_isSeriesCategory)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  _TabButton(label: 'MOVIES', active: _tab == 0, onTap: () => _selectTab(0)),
                  const SizedBox(width: 8),
                  _TabButton(label: 'SERIES', active: _tab == 1, onTap: () => _selectTab(1)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListenableBuilder(
      listenable: Listenable.merge([_moviesController, _seriesController]),
      builder: (context, _) {
        final items = _items;
        final isSeries = _usingSeries;

        if (_initialLoading && items.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (_error != null && items.isEmpty) {
          return ListErrorState(
            message: isSeries ? 'Failed to load series' : 'Failed to load movies',
            onRetry: () => _reloadActive(search: _search),
          );
        }
        if (items.isEmpty) {
          return ListEmptyState(
            icon: Icons.search_off,
            message: isSeries ? 'No series found' : 'No movies found',
            hasFilters: _search.trim().isNotEmpty,
            onClear: () {
              _debounce?.cancel();
              setState(() {
                _search = '';
                _searchController.clear();
              });
              _reloadActive();
            },
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
                loadingMore: _loadingMore,
                hasMore: _hasMore,
                doneLabel: "YOU'RE ALL CAUGHT UP — $_title",
              );
            }
            final m = items[index];
            final series = isSeries;
            return MovieCard(
              movie: m,
              isSeries: series,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => series ? SeriesDetailScreen(series: m) : MovieDetailScreen(movie: m),
                ),
              ),
            );
          },
        );
      },
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