import 'package:flutter/foundation.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/models/pagination.dart';
import 'package:tulabe/services/api_client.dart';

/// Shared paged-catalog base for list screens (Movies, Series, ...).
///
/// Mirrors the web's `useInfiniteMovies` / `useInfiniteSeries`: a fixed page
/// size (default 20), optional filters, and "next page" loads that trigger
/// when the grid scrolls near the bottom (the Flutter equivalent of the web's
/// IntersectionObserver sentinel).
abstract class PagedCatalogController<T> extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  final String apiPath;
  final String listKey;
  final T Function(Map<String, dynamic>) fromJson;
  final int pageSize;

  PagedCatalogController({
    required this.apiPath,
    required this.listKey,
    required this.fromJson,
    this.pageSize = 20,
  });

  final List<T> _items = <T>[];
  List<T> get items => List.unmodifiable(_items);

  // Filter options shown in the filters sheet (active genres + active VJs).
  List<Genre> _genres = const [];
  List<VJ> _vjs = const [];
  List<Genre> get genres => _genres;
  List<VJ> get vjs => _vjs;

  int _page = 0;
  int _totalPages = 1;
  int _total = 0;

  bool _initialLoading = false;
  bool _loadingMore = false;
  String? _error;

  bool get initialLoading => _initialLoading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _page < _totalPages;
  bool get isEmpty => _items.isEmpty;
  String? get error => _error;
  int get total => _total;

  // Current query state, kept so loadMore() continues the same filtered query.
  String _search = '';
  String? _genreId;
  String? _vjId;
  Map<String, String> _extra = const {};

  /// Fetches active genres + active VJs once, for the filters sheet.
  Future<void> loadFilterOptions() async {
    try {
      final results = await Future.wait([
        _fetchList('/genres', 'genres', Genre.fromJson),
        _fetchList('/vjs?status=active&limit=50', 'vjs', VJ.fromJson),
      ]);
      _genres = results[0] as List<Genre>;
      _vjs = results[1] as List<VJ>;
      notifyListeners();
    } catch (_) {
      // Non-fatal: the sheet falls back to no preloaded options.
    }
  }

  /// Starts a fresh query, replacing the current list. Subclasses with extra
  /// filters (latest/year/status) pass them via [extra].
  Future<void> loadFirstPage({
    String search = '',
    String? genreId,
    String? vjId,
    Map<String, String> extra = const {},
  }) async {
    _search = search;
    _genreId = genreId;
    _vjId = vjId;
    _extra = extra;
    _items.clear();
    _page = 0;
    _totalPages = 1;
    _error = null;
    _initialLoading = true;
    notifyListeners();
    await _fetchPage(1);
  }

  /// Fetches the next page when the grid scrolls near the bottom.
  Future<void> loadMore() async {
    if (_initialLoading || _loadingMore || !hasMore) return;
    await _fetchPage(_page + 1);
  }

  Future<void> _fetchPage(int page) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': pageSize,
    };
    if (_search.isNotEmpty) params['search'] = _search;
    final genreId = _genreId;
    if (genreId != null && genreId.isNotEmpty) params['genre_id'] = genreId;
    final vjId = _vjId;
    if (vjId != null && vjId.isNotEmpty) params['vj_id'] = vjId;
    params.addAll(_extra);

    try {
      final response = await _apiClient.dio.get(apiPath, queryParameters: params);
      final body = response.data;

      List raw = const [];
      Pagination? pagination;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          final rawList = data[listKey];
          if (rawList is List) raw = rawList;
          final rawPagination = data['pagination'];
          if (rawPagination is Map<String, dynamic>) {
            pagination = Pagination.fromJson(rawPagination);
          }
        }
      }

      _items.addAll(raw.whereType<Map<String, dynamic>>().map(fromJson));
      _page = page;
      _totalPages = pagination?.totalPages ?? (raw.isEmpty ? page : page + 1);
      _total = pagination?.total ?? _items.length;
    } catch (e) {
      _error = e.toString();
    }

    _initialLoading = false;
    _loadingMore = false;
    notifyListeners();
  }

  Future<List<T2>> _fetchList<T2>(
    String path,
    String key,
    T2 Function(Map<String, dynamic>) parser,
  ) async {
    final response = await _apiClient.dio.get(path);
    final body = response.data;
    List raw = const [];
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        final list = data[key];
        if (list is List) raw = list;
      }
    }
    return raw.whereType<Map<String, dynamic>>().map(parser).toList(growable: false);
  }
}