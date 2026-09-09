import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tulabe/controllers/vj_detail_controller.dart';
import 'package:tulabe/my_widgets/list_state_widgets.dart';
import 'package:tulabe/my_widgets/movie_card.dart';
import 'package:tulabe/my_widgets/responsive_grid.dart';
import 'package:tulabe/screens/movie_detail_screen.dart';
import 'package:tulabe/screens/series_detail_screen.dart';
import '../theme/app_colors.dart';

/// VJ detail page — mirrors the web `/vjs/[id]`: VJ header, search, a
/// Movies/Series toggle with a genre filter drawer, and that VJ's content
/// (movies via `/vjs/:id/movies`, series via `/series?vj_id=`), merged into
/// one newest-first grid on the default "all" tab. Wired via
/// [VJDetailController].
class VJDetailScreen extends StatefulWidget {
  final String vjId;
  const VJDetailScreen({super.key, required this.vjId});

  @override
  State<VJDetailScreen> createState() => _VJDetailScreenState();
}

class _VJDetailScreenState extends State<VJDetailScreen> {
  late final VJDetailController _controller =
      VJDetailController(vjRef: widget.vjId);
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _controller.load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _controller.loadMore();
    }
  }

  void _jumpTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _controller.reload(search: value, genreId: _controller.genreId);
      _jumpTop();
    });
  }

  void _reload() {
    _controller.reload(search: _controller.search, genreId: _controller.genreId);
    _jumpTop();
  }

  void _clearFilters() {
    _textController.clear();
    _debounce?.cancel();
    _controller.clearFilters();
    _jumpTop();
  }

  void _openFilters() {
    final vj = _controller.vj;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) {
        String pending = _controller.genreId;
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
                      vj == null
                          ? 'FILTER CONTENT'
                          : 'FILTER ${vj.name.replaceFirst('VJ ', '').toUpperCase()}\'S CONTENT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Narrow down what you want to watch.',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 20),
                    const _FilterLabel('GENRE'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: pending.isEmpty,
                          onTap: () => setSheetState(() => pending = ''),
                        ),
                        ..._controller.genres
                            .where((g) => g.isActive)
                            .map((g) => _FilterChip(
                                  label: g.name.toUpperCase(),
                                  selected: pending == '${g.id}',
                                  onTap: () => setSheetState(
                                    () => pending = pending == '${g.id}' ? '' : '${g.id}',
                                  ),
                                )),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        _controller.reload(
                          search: _controller.search,
                          genreId: pending,
                        );
                        _jumpTop();
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0118),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white60),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.vjLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (_controller.vjFailed) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'VJ not found',
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Browse all VJs',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildSearch(),
              _buildControls(),
              const SizedBox(height: 4),
              Expanded(child: _buildContent()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final vj = _controller.vj!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2),
                ),
                child: ClipOval(
                  child: vj.imageUrl.isNotEmpty
                      ? Image.network(
                          vj.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _VJInitial(name: vj.name),
                        )
                      : _VJInitial(name: vj.name),
                ),
              ),
              if (vj.isActive)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0A0118), width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        vj.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1),
                      ),
                    ),
                    if (vj.isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3)),
                        child: const Text('LIVE',
                            style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  vj.description.isNotEmpty
                      ? vj.description
                      : 'Full catalogue of narrated movies & series.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    final vj = _controller.vj;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: SizedBox(
        height: 38,
        child: TextField(
          controller: _textController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText:
                "Search ${(vj?.name ?? '').replaceFirst('VJ ', '')}'s content…",
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
    );
  }

  Widget _buildControls() {
    final contentType = _controller.contentType;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          _TabButton(label: 'MOVIES', active: contentType == 1, onTap: () {
            _controller.setContentType(contentType == 1 ? 0 : 1);
            _jumpTop();
          }),
          const SizedBox(width: 8),
          _TabButton(label: 'SERIES', active: contentType == 2, onTap: () {
            _controller.setContentType(contentType == 2 ? 0 : 2);
            _jumpTop();
          }),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_list, color: Colors.white60, size: 14),
                  const SizedBox(width: 5),
                  const Text(
                    'FILTERS',
                    style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                  if (_controller.genreId.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final c = _controller;
    final ctype = c.contentType;

    final items = ctype == 0 ? c.feed : (ctype == 1 ? c.movies : c.series);
    final loading = ctype == 0
        ? c.moviesLoading || c.seriesLoading
        : (ctype == 1 ? c.moviesLoading : c.seriesLoading);
    final error = ctype == 0
        ? (c.moviesError ?? c.seriesError)
        : (ctype == 1 ? c.moviesError : c.seriesError);

    final emptyMessage = ctype == 0
        ? 'No content found'
        : ctype == 1
            ? 'No movies found'
            : 'No series found';
    final hasFilters =
        c.search.trim().isNotEmpty || c.genreId.isNotEmpty;

    if (loading && items.isEmpty) {
      return const _SkeletonGrid();
    }
    if (error != null && items.isEmpty) {
      return ListErrorState(message: 'Failed to load content', onRetry: _reload);
    }
    if (items.isEmpty) {
      return ListEmptyState(
        icon: Icons.movie_outlined,
        message: emptyMessage,
        hasFilters: hasFilters,
        onClear: _clearFilters,
      );
    }

    final loadingMore = ctype == 0
        ? c.moviesLoadingMore || c.seriesLoadingMore
        : (ctype == 1 ? c.moviesLoadingMore : c.seriesLoadingMore);
    final hasMore = ctype == 0
        ? c.moviesHasMore || c.seriesHasMore
        : (ctype == 1 ? c.moviesHasMore : c.seriesHasMore);
    final doneLabel = ctype == 0
        ? 'ALL CONTENT LOADED'
        : ctype == 1
            ? 'ALL MOVIES LOADED'
            : 'ALL SERIES LOADED';

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
                final item = items[index];
                final movie = item.movie;
                return MovieCard(
                  movie: movie,
                  isSeries: item.isSeries,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => item.isSeries
                          ? SeriesDetailScreen(series: movie)
                          : MovieDetailScreen(movie: movie),
                    ),
                  ),
                );
              },
              childCount: items.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ListFooter(
            loadingMore: loadingMore,
            hasMore: hasMore,
            doneLabel: doneLabel,
          ),
        ),
      ],
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

class _VJInitial extends StatelessWidget {
  final String name;
  const _VJInitial({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 26, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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