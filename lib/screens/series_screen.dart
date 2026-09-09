import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tulabe/controllers/series_controller.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/my_widgets/filters_sheet.dart';
import 'package:tulabe/my_widgets/list_state_widgets.dart';
import 'package:tulabe/my_widgets/responsive_grid.dart';
import 'package:tulabe/screens/series_detail_screen.dart';
import '../theme/app_colors.dart';

/// Series browse tab — infinite-scroll grid of all series with search +
/// filters, mirroring the web /series page (`useInfiniteSeries`, limit 20).
class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  final SeriesController _controller = SeriesController();
  final ScrollController _scrollController = ScrollController();

  String _search = '';
  String _genre = '';
  String _vj = '';
  String _status = '';

  Timer? _debounce;
  bool _filtersChanged = false;

  bool get _hasFilters => _genre.isNotEmpty || _vj.isNotEmpty || _status.isNotEmpty;

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
    final statusValue = _status.toLowerCase() == 'ongoing'
        ? 'ongoing'
        : _status.toLowerCase() == 'completed'
            ? 'completed'
            : '';
    await _controller.reload(
      search: _search,
      genreId: _genreId,
      vjId: _vjId,
      status: statusValue,
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
        showLatest: false,
        latestOnly: false,
        showYear: false,
        showStatus: true,
        activeGenre: _genre,
        activeVJ: _vj,
        activeYear: '',
        activeStatus: _status,
        genreLabels: genreLabels,
        vjLabels: vjLabels,
        onLatestChanged: (_) {},
        onGenreChanged: (v) {
          _genre = v;
          _filtersChanged = true;
        },
        onVJChanged: (v) {
          _vj = v;
          _filtersChanged = true;
        },
        onYearChanged: (_) {},
        onStatusChanged: (v) {
          _status = v;
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
      _status = '';
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
                      hintText: 'Search series…',
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
                  message: 'Failed to load series',
                  onRetry: _reload,
                );
              }

              final series = _controller.items;

              if (series.isEmpty) {
                return ListEmptyState(
                  icon: Icons.tv,
                  message: 'No series found',
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
                        (context, index) {
                          final s = series[index];
                          return _SeriesCard(
                            series: s,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SeriesDetailScreen(
                                  series: Movie.fromSeries(s),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: series.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ListFooter(
                      loadingMore: _controller.loadingMore,
                      hasMore: _controller.hasMore,
                      doneLabel: 'ALL SERIES LOADED',
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

/// A series card — mirrors the web's SeriesCard: poster with VJ badge,
/// "ON AIR" status, title, and meta (year · seasons · genre · VJ).
class _SeriesCard extends StatelessWidget {
  final Series series;
  final VoidCallback onTap;
  const _SeriesCard({required this.series, required this.onTap});

  bool get _isOngoing => series.status.toLowerCase() == 'ongoing';

  String? _firstComma(String value) {
    if (value.isEmpty) return null;
    return value.split(',')[0].trim();
  }

  @override
  Widget build(BuildContext context) {
    final vjName = _firstComma(series.vjNames)?.toUpperCase() ?? '';
    final genre = _firstComma(series.genreNames) ?? '';
    final year = series.releaseYear > 0 ? '${series.releaseYear}' : '';
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
                      series.posterUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.cardBg,
                        child: const Icon(Icons.tv, color: AppColors.textTertiary, size: 32),
                      ),
                    ),
                    if (vjName.isNotEmpty)
                      Positioned(
                        top: 6,
                        left: 6,
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
                              const Icon(Icons.radio, size: 9, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                vjName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_isOngoing)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'ON AIR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 6,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
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
            series.title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (year.isNotEmpty) year,
              if (series.totalSeasons > 0)
                '${series.totalSeasons} Season${series.totalSeasons != 1 ? 's' : ''}',
              if (genre.isNotEmpty) genre,
              if (vjName.isNotEmpty) vjName,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
          ),
        ],
      ),
    );
  }
}