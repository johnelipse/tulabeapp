import 'package:flutter/foundation.dart';
import 'package:tulabe/controllers/paged_catalog_controller.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/services/api_client.dart';

/// One entry in a VJ's content feed (movie or series) with its creation
/// timestamp, used to merge the two pages into a single newest-first grid
/// (mirrors the web `/vjs/[id]` interleaved feed).
class VJFeedItem {
  final Movie movie;
  final bool isSeries;
  final DateTime created;

  const VJFeedItem({
    required this.movie,
    required this.isSeries,
    required this.created,
  });
}

/// Paged movies for one VJ via `GET /api/vjs/:id/movies` (StreamMovie-shaped
/// items, newest first).
class _VJMoviesController extends PagedCatalogController<VJFeedItem> {
  _VJMoviesController(String vjId)
      : super(
          apiPath: '/vjs/$vjId/movies',
          listKey: 'movies',
          fromJson: (json) {
            final sm = StreamMovie.fromJson(json);
            return VJFeedItem(
              movie: Movie.fromStreamMovie(sm),
              isSeries: false,
              created: sm.createdAt,
            );
          },
        );

  Future<void> reload({String search = '', String genreId = ''}) =>
      super.loadFirstPage(
        search: search,
        genreId: genreId.isEmpty ? null : genreId,
      );
}

/// Paged series for one VJ via `GET /api/series?vj_id=...` (Series-shaped
/// items, newest first).
class _VJSeriesController extends PagedCatalogController<VJFeedItem> {
  _VJSeriesController(String vjId)
      : super(
          apiPath: '/series',
          listKey: 'series',
          fromJson: (json) {
            final s = Series.fromJson(json);
            return VJFeedItem(
              movie: Movie.fromSeries(s),
              isSeries: true,
              created: s.createdAt,
            );
          },
        );

  Future<void> reload({
    required String vjId,
    String search = '',
    String genreId = '',
  }) =>
      super.loadFirstPage(
        search: search,
        genreId: genreId.isEmpty ? null : genreId,
        vjId: vjId,
      );
}

/// Drives the VJ detail screen (`/vjs/[id]`): the VJ header, a Movies/Series
/// toggle, optional search + genre filter, and two paged lists merged into
/// one feed for the default "all" tab.
///
/// Mirrors the web `useVJ` + `useInfiniteVJMovies` + `useInfiniteSeries`.
class VJDetailController extends ChangeNotifier {
  VJDetailController({required this.vjRef}) {
    _movies.addListener(notifyListeners);
    _series.addListener(notifyListeners);
  }

  /// Numeric id or slug (the API resolves both).
  final String vjRef;

  final ApiClient _apiClient = ApiClient();
  late final _VJMoviesController _movies = _VJMoviesController(vjRef);
  late final _VJSeriesController _series = _VJSeriesController(vjRef);

  VJ? _vj;
  bool _vjLoading = true;
  bool _vjFailed = false;
  int _contentType = 0; // 0 all, 1 movies, 2 series
  String _search = '';
  String _genreId = '';

  VJ? get vj => _vj;
  bool get vjLoading => _vjLoading;
  bool get vjFailed => _vjFailed;
  int get contentType => _contentType;
  String get search => _search;
  String get genreId => _genreId;

  List<Genre> get genres => _movies.genres;

  List<VJFeedItem> get movies => _movies.items;
  List<VJFeedItem> get series => _series.items;

  bool get moviesLoading => _movies.initialLoading && _movies.items.isEmpty;
  bool get moviesLoadingMore => _movies.loadingMore;
  bool get moviesHasMore => _movies.hasMore;
  String? get moviesError => _movies.error;

  bool get seriesLoading => _series.initialLoading && _series.items.isEmpty;
  bool get seriesLoadingMore => _series.loadingMore;
  bool get seriesHasMore => _series.hasMore;
  String? get seriesError => _series.error;

  /// Newest-first merge of movies + series. Both source lists grow only by
  /// appending strictly-older pages, so the merge-join is prefix-stable:
  /// extending either input's tail can never reorder an already-rendered
  /// position (this is the fix the web describes for its old "series shifts
  /// down" bug).
  List<VJFeedItem> get feed {
    final m = movies;
    final s = series;
    final merged = <VJFeedItem>[];
    var i = 0;
    var j = 0;
    while (i < m.length && j < s.length) {
      if (!m[i].created.isAfter(s[j].created)) {
        merged.add(m[i++]);
      } else {
        merged.add(s[j++]);
      }
    }
    merged.addAll(m.sublist(i));
    merged.addAll(s.sublist(j));
    return merged;
  }

  void setContentType(int value) {
    if (_contentType == value) return;
    _contentType = value;
    notifyListeners();
  }

  /// Fetches the VJ header, then both content lists (and genre options).
  Future<void> load() async {
    _vjLoading = true;
    _vjFailed = false;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get('/vjs/$vjRef');
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          final rawVj = data['vj'];
          if (rawVj is Map<String, dynamic>) _vj = VJ.fromJson(rawVj);
        }
      }
    } catch (_) {
      // 404 / network failure → vjFailed below; the screen shows "not found".
    }
    _vjFailed = _vj == null;
    _vjLoading = false;
    notifyListeners();

    await _movies.loadFilterOptions();
    await _reloadLists();
  }

  /// Restarts both lists with the current search + genre filter.
  Future<void> reload({String search = '', String genreId = ''}) async {
    _search = search;
    _genreId = genreId;
    await _reloadLists();
  }

  Future<void> _reloadLists() async {
    final vjId = _vj == null ? '' : '${_vj!.id}';
    await Future.wait([
      _movies.reload(search: _search, genreId: _genreId),
      if (vjId.isNotEmpty)
        _series.reload(vjId: vjId, search: _search, genreId: _genreId),
    ]);
  }

  void clearFilters() {
    reload(search: '', genreId: '');
  }

  /// Loads the next page of whichever list(s) are visible.
  Future<void> loadMore() async {
    if (_contentType == 1) {
      await _movies.loadMore();
    } else if (_contentType == 2) {
      await _series.loadMore();
    } else {
      await Future.wait([
        if (_movies.hasMore && !_movies.loadingMore) _movies.loadMore(),
        if (_series.hasMore && !_series.loadingMore) _series.loadMore(),
      ]);
    }
  }

  @override
  void dispose() {
    _movies.removeListener(notifyListeners);
    _series.removeListener(notifyListeners);
    _movies.dispose();
    _series.dispose();
    super.dispose();
  }
}