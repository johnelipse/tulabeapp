import 'package:flutter/material.dart' hide SearchController;
import 'package:tulabe/controllers/search_controller.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/my_widgets/list_state_widgets.dart';
import 'package:tulabe/my_widgets/responsive_grid.dart';
import 'package:tulabe/screens/movie_detail_screen.dart';
import 'package:tulabe/screens/series_detail_screen.dart';
import '../theme/app_colors.dart';

/// Global search screen — mirrors the web /search page.
/// Wired to `GET /api/search` + `/api/search/suggestions` via
/// [SearchController].
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchController _controller = SearchController();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSuggestions = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _textController.dispose();
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
    _controller.onQueryChanged(value);
    setState(() => _showSuggestions = true);
  }

  void _submitSearch() {
    setState(() => _showSuggestions = false);
  }

  void _clearSearch() {
    _textController.clear();
    _controller.onQueryChanged('');
    setState(() => _showSuggestions = false);
  }

  void _onSuggestionTap(Suggestion s) {
    setState(() => _showSuggestions = false);
    final movie = Movie(
      id: s.id,
      title: s.title,
      imageUrl: s.thumbnailUrl,
      badge: _firstVj(s.vjNames),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => s.type == 'series'
            ? SeriesDetailScreen(series: movie)
            : MovieDetailScreen(movie: movie),
      ),
    );
  }

  void _onResultTap(SearchResult r) {
    final movie = Movie(
      id: r.id,
      title: r.title,
      imageUrl: r.thumbnailUrl,
      badge: _firstVj(r.vjNames),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => r.type == 'series'
            ? SeriesDetailScreen(series: movie)
            : MovieDetailScreen(movie: movie),
      ),
    );
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) {
        String? pendingGenreId = _controller.genreId;
        String? pendingVjId = _controller.vjId;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FILTER RESULTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Narrow your search by VJ or genre.',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 20),
                    if (_controller.vjs.isNotEmpty) ...[
                      const _FilterLabel('VJ'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: pendingVjId == null,
                            onTap: () => setSheetState(() => pendingVjId = null),
                          ),
                          ..._controller.vjs.map((v) => _FilterChip(
                                label: v.name.replaceFirst('VJ ', '').toUpperCase(),
                                selected: pendingVjId == '${v.id}',
                                onTap: () => setSheetState(
                                  () => pendingVjId =
                                      pendingVjId == '${v.id}' ? null : '${v.id}',
                                ),
                              )),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_controller.genres.isNotEmpty) ...[
                      const _FilterLabel('GENRE'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: pendingGenreId == null,
                            onTap: () => setSheetState(() => pendingGenreId = null),
                          ),
                          ..._controller.genres
                              .where((g) => g.isActive)
                              .map((g) => _FilterChip(
                                    label: g.name.toUpperCase(),
                                    selected: pendingGenreId == '${g.id}',
                                    onTap: () => setSheetState(
                                      () => pendingGenreId =
                                          pendingGenreId == '${g.id}' ? null : '${g.id}',
                                    ),
                                  )),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        _controller.applyFilters(
                          genreId: pendingGenreId,
                          vjId: pendingVjId,
                        );
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text(
                            'APPLY FILTERS',
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0118),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
              children: [
                _buildSearchBar(),
                if (_controller.showResults) _buildTypeTabs(),
                const SizedBox(height: 8),
                Expanded(
                  child: _controller.showResults ? _buildResults() : _buildIdle(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final query = _controller.query;
    final suggestions = _showSuggestions ? _controller.suggestions : const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              children: [
                TextField(
                  controller: _textController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _submitSearch(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    hintText: 'Search movies, series, VJs…',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.search, color: Colors.white30, size: 18),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                  ),
                ),
                if (query.isNotEmpty)
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _clearSearch,
                      child: const Icon(Icons.close, color: Colors.white30, size: 16),
                    ),
                  ),
                // Suggestions dropdown
                if (suggestions.isNotEmpty)
                  Positioned(
                    top: 46,
                    left: 0,
                    right: 0,
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'SUGGESTIONS',
                                style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                          ...suggestions.map((s) => _SuggestionRow(
                                suggestion: s,
                                onTap: () => _onSuggestionTap(s),
                              )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTabs() {
    final type = _controller.contentType;
    final hasFilters = _controller.genreId != null || _controller.vjId != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _TypeTab(label: 'ALL', active: type == 'all', onTap: () => _controller.setContentType('all')),
          const SizedBox(width: 8),
          _TypeTab(label: 'MOVIES', active: type == 'movies', onTap: () => _controller.setContentType('movies')),
          const SizedBox(width: 8),
          _TypeTab(label: 'SERIES', active: type == 'series', onTap: () => _controller.setContentType('series')),
          const Spacer(),
          ClipOval(
            child: Material(
              color: Colors.white.withValues(alpha: 0.04),
              child: InkWell(
                onTap: _openFilters,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.filter_list, color: Colors.white60, size: 18),
                      if (hasFilters)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final results = _controller.results;
    final total = _controller.total;
    final q = _controller.debouncedQuery;
    final searching = _controller.isSearching;
    final error = _controller.error;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            searching
                ? 'SEARCHING…'
                : results.isEmpty
                    ? 'NO RESULTS FOR "$q"'
                    : '${_fmt(total)} RESULT${total != 1 ? 'S' : ''} FOR "$q"',
            style: const TextStyle(
              color: Colors.white30,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          if (error != null)
            ListErrorState(
              message: error,
              onRetry: () => _controller.onQueryChanged(_controller.query),
            )
          else if (searching)
            const _SkeletonGrid()
          else if (results.isEmpty)
            _NoResults(
              onClear: () {
                _controller.clearFilters();
                _controller.setContentType('all');
              },
            )
          else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: movieColumns(context),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: movieCardExtent(context),
              ),
              itemCount: results.length,
              itemBuilder: (context, index) => _ResultCard(
                result: results[index],
                onTap: () => _onResultTap(results[index]),
              ),
            ),
            ListFooter(
              loadingMore: _controller.isLoadingMore,
              hasMore: _controller.hasMore,
              doneLabel: 'END OF RESULTS',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdle() {
    final genres = _controller.idleGenres;
    final popular = _controller.popularMovies;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Browse by genre
          if (genres.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'BROWSE BY GENRE',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: genres
                  .map((g) => _GenreChip(
                        label: g.name.toUpperCase(),
                        onTap: () {
                          _textController.text = g.name;
                          _controller.searchGenre(g.name);
                          setState(() => _showSuggestions = false);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
          // Popular now
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'POPULAR NOW',
              style: TextStyle(
                color: Colors.white30,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
          if (popular.isEmpty)
            const _SkeletonGrid()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: movieColumns(context),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: movieCardExtent(context),
              ),
              itemCount: popular.length,
              itemBuilder: (context, index) {
                final m = popular[index];
                final movie = Movie.fromStreamMovie(m);
                return _ResultCard(
                  result: SearchResult(
                    id: m.id,
                    type: 'movie',
                    title: m.title,
                    thumbnailUrl: m.thumbnailUrl,
                    releaseYear: m.releaseYear,
                    genreNames: m.genreNames,
                    vjNames: m.vjNames,
                    status: '',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  static String? _firstVj(String vjNames) {
    final parts = vjNames
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.first;
  }

  static String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── Private widgets ─────────────────────────────────────────────────

class _TypeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypeTab({required this.label, required this.active, required this.onTap});

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
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GenreChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final Suggestion suggestion;
  final VoidCallback onTap;
  const _SuggestionRow({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final vjName = (suggestion.vjNames)
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final firstVj = vjName.isEmpty ? null : vjName.first.replaceFirst('VJ ', '').toUpperCase();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  suggestion.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.surface,
                    child: Icon(
                      suggestion.type == 'series' ? Icons.tv : Icons.movie,
                      color: Colors.white24,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    suggestion.type.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  if (firstVj != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.radio, color: AppColors.primary, size: 9),
                        const SizedBox(width: 3),
                        Text(
                          firstVj,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;
  const _ResultCard({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final vjParts = result.vjNames
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final vjName = vjParts.isEmpty ? null : vjParts.first.replaceFirst('VJ ', '').toUpperCase();
    final year = result.releaseYear > 0 ? '${result.releaseYear}' : '';
    final genreParts = result.genreNames
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final genre = genreParts.isNotEmpty ? genreParts.first : '';
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
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      result.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.cardBg,
                        child: Icon(
                          result.type == 'series' ? Icons.tv : Icons.movie,
                          color: AppColors.textTertiary,
                          size: 30,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      left: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          result.type.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 6,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    if (vjName != null)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6A00), Color(0xFFEE0979)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.radio, size: 8, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                vjName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 6,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
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
            result.title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [year, genre, vjName ?? ''].where((s) => s.isNotEmpty).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white30,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
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

class _NoResults extends StatelessWidget {
  final VoidCallback onClear;
  const _NoResults({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(Icons.search_off, color: Colors.white24, size: 28),
            ),
            const SizedBox(height: 12),
            const Text('No results found', style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 4),
            const Text(
              'Try a different title or browse by genre above',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: movieColumns(context),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: movieCardExtent(context),
      ),
      itemCount: 14,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 9,
              width: 80,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 8,
              width: 55,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        );
      },
    );
  }
}