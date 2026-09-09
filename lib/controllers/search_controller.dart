import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/services/api_client.dart';

/// Drives the global search screen — mirrors the web's `useSearch` +
/// `useSearchSuggestions` hooks backed by the Go API (`/api/search` and
/// `/api/search/suggestions`). Handles:
///
/// * 350 ms debounced search with type tabs + genre/VJ filters
/// * Typeahead suggestions (up to 7, cached 2 min server-side)
/// * Paginated infinite-scroll for results
/// * Idle state data (active genres + popular movies)
class SearchController extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  // ── Idle state ──────────────────────────────────────────────────────
  List<Genre> _idleGenres = const [];
  List<StreamMovie> _popularMovies = const [];
  List<Genre> get idleGenres => _idleGenres;
  List<StreamMovie> get popularMovies => _popularMovies;

  // ── Search state ────────────────────────────────────────────────────
  String _query = '';
  String _debouncedQuery = '';
  String _contentType = 'all'; // all | movies | series
  String? _genreId;
  String? _vjId;

  // Filter options loaded lazily (shared with filter bottom sheet).
  List<Genre> _genres = const [];
  List<VJ> _vjs = const [];
  List<Genre> get genres => _genres;
  List<VJ> get vjs => _vjs;

  List<SearchResult> _results = const [];
  int _total = 0;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  String? _error;

  // Pagination
  int _page = 0;
  int _totalPages = 1;

  List<SearchResult> get results => List.unmodifiable(_results);
  int get total => _total;
  bool get isSearching => _isSearching;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _page < _totalPages;
  String get query => _query;
  String get debouncedQuery => _debouncedQuery;
  String get contentType => _contentType;
  String? get genreId => _genreId;
  String? get vjId => _vjId;
  String? get error => _error;
  bool get showResults => _debouncedQuery.trim().length >= 2;

  Timer? _debounce;

  SearchController() {
    _loadIdle();
    _loadFilterOptions();
  }

  // ── Idle state ──────────────────────────────────────────────────────

  Future<void> _loadIdle() async {
    final results = await Future.wait([
      _getList('/genres', 'genres', Genre.fromJson),
      _getList('/movies?limit=14', 'movies', StreamMovie.fromJson),
    ]);
    _idleGenres = (results[0] as List<Genre>)
        .where((g) => g.isActive)
        .toList(growable: false);
    _popularMovies = results[1] as List<StreamMovie>;
    notifyListeners();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final results = await Future.wait([
        _getList('/genres', 'genres', Genre.fromJson),
        _getList('/vjs?status=active&limit=50', 'vjs', VJ.fromJson),
      ]);
      _genres = results[0] as List<Genre>;
      _vjs = results[1] as List<VJ>;
      notifyListeners();
    } catch (_) {
      // Non-fatal: filter sheet shows without options.
    }
  }

  // ── Suggestions ─────────────────────────────────────────────────────

  List<Suggestion> _suggestions = const [];
  List<Suggestion> get suggestions => _suggestions;

  Future<void> fetchSuggestions(String q) async {
    if (q.trim().length < 2) {
      if (_suggestions.isNotEmpty) {
        _suggestions = const [];
        notifyListeners();
      }
      return;
    }
    try {
      final response = await _apiClient.dio.get('/search/suggestions', queryParameters: {'q': q.trim()});
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          _suggestions = Suggestion.listFromJson(data['suggestions']);
        }
      }
    } catch (_) {
      _suggestions = const [];
    }
    notifyListeners();
  }

  // ── Search ──────────────────────────────────────────────────────────

  /// Called by the text field on every keystroke. Debounces internally.
  void onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _debouncedQuery = value;
      _fetchResults(reset: true);
      fetchSuggestions(value);
    });
    notifyListeners();
  }

  void setContentType(String type) {
    if (_contentType == type) return;
    _contentType = type;
    if (showResults) _fetchResults(reset: true);
    notifyListeners();
  }

  void applyFilters({String? genreId, String? vjId}) {
    _genreId = genreId;
    _vjId = vjId;
    if (showResults) _fetchResults(reset: true);
    notifyListeners();
  }

  void clearFilters() {
    if (_genreId == null && _vjId == null) return;
    _genreId = null;
    _vjId = null;
    if (showResults) _fetchResults(reset: true);
    notifyListeners();
  }

  /// For the "browse by genre" chips in idle state.
  void searchGenre(String name) {
    _query = name;
    _debouncedQuery = name;
    _fetchResults(reset: true);
    fetchSuggestions(name);
    notifyListeners();
  }

  Future<void> _fetchResults({bool reset = false}) async {
    if (reset) {
      _results = const [];
      _page = 0;
      _totalPages = 1;
      _total = 0;
      _error = null;
    }

    final q = _debouncedQuery.trim();
    if (q.length < 2) return;

    if (reset) {
      _isSearching = true;
    } else {
      _isLoadingMore = true;
    }
    notifyListeners();

    try {
      final params = <String, dynamic>{
        'q': q,
        'type': _contentType,
        'page': _page + 1,
        'limit': 20,
      };
      if (_genreId != null && _genreId!.isNotEmpty) params['genre_id'] = _genreId;
      if (_vjId != null && _vjId!.isNotEmpty) params['vj_id'] = _vjId;

      final response = await _apiClient.dio.get('/search', queryParameters: params);
      final body = response.data;

      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          final raw = data['results'];
          if (raw is List) {
            _results = [..._results, ...SearchResult.listFromJson(raw)];
          }
          final pagination = data['pagination'];
          if (pagination is Map<String, dynamic>) {
            _page = (pagination['page'] as num?)?.toInt() ?? _page + 1;
            _totalPages = (pagination['total_pages'] as num?)?.toInt() ?? _totalPages;
            _total = (pagination['total'] as num?)?.toInt() ?? _total;
          }
        }
      }
    } catch (e) {
      _error = e.toString();
    }

    _isSearching = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore || _isSearching) return;
    await _fetchResults();
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  Future<List<T>> _getList<T>(
    String path,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final response = await _apiClient.dio.get(path);
      final body = response.data;
      List raw = const [];
      if (body is Map<String, dynamic>) {
        final inner = body['data'];
        if (inner is Map<String, dynamic>) {
          final list = inner[key];
          if (list is List) raw = list;
        }
      }
      return raw.whereType<Map<String, dynamic>>().map(fromJson).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}