import 'package:tulabe/models/movies.dart';
import 'package:tulabe/services/api_client.dart';

/// Aggregated payload for the home tab, mirroring the web homepage sections.
class HomeData {
  final List<HeroItem> hero;
  final List<StreamMovie> latestMovies;
  final List<VJ> vjs;
  final List<Series> latestSeries;
  final List<StreamMovie> forYou;
  final List<Genre> genres;
  final Map<Genre, List<StreamMovie>> genreMovies;

  const HomeData({
    this.hero = const [],
    this.latestMovies = const [],
    this.vjs = const [],
    this.latestSeries = const [],
    this.forYou = const [],
    this.genres = const [],
    this.genreMovies = const {},
  });
}

/// Fetches all the data needed to render the home tab from the Go API.
///
/// Mirrors the data flow in the web `apps/web/app/page.tsx` homepage:
/// Hero -> Latest Movies -> Available VJs -> Latest Series -> For You ->
/// Genre rows. Continue Watching is UI-only (no local progress store yet).
class HomeController {
  final ApiClient _apiClient = ApiClient();
  static const int _limit = 30;
  static const int _heroFallbackLimit = 3;
  static const int _homeGenreLimit = 4;
  static const List<String> _priorityHomeGenres = ['action', 'romance'];

  /// Fetches everything needed for the home tab in parallel.
  Future<HomeData> fetchHomeData() async {
    final results = await Future.wait([
      _fetchHero(),
      _fetchLatestMovies(),
      _fetchVJs(),
      _fetchLatestSeries(),
      _fetchForYou(),
      _fetchGenres(),
    ]);

    final hero = results[0] as List<HeroItem>;
    final latestMovies = results[1] as List<StreamMovie>;
    final vjs = results[2] as List<VJ>;
    final latestSeries = results[3] as List<Series>;
    final forYou = results[4] as List<StreamMovie>;
    final genres = results[5] as List<Genre>;

    final genreMovies = await _fetchGenreMovies(genres, latestMovies);

    return HomeData(
      hero: hero,
      latestMovies: latestMovies,
      vjs: vjs,
      latestSeries: latestSeries,
      forYou: forYou,
      genres: genres,
      genreMovies: genreMovies,
    );
  }

  Future<List<HeroItem>> _fetchHero() async {
    final items = await _getList('/movies-hero', 'items', HeroItem.fromJson);
    if (items.isNotEmpty) return items;

    // Fallback: curated latest, then newest — top 3 only.
    final fallback = await _fetchLatestMovies();
    final slideMovies = fallback.length > _heroFallbackLimit
        ? fallback.sublist(0, _heroFallbackLimit)
        : fallback;
    return slideMovies
        .map(
          (m) => HeroItem(
            type: 'movie',
            id: m.id,
            title: m.title,
            description: m.description,
            imageUrl: m.heroImageUrl.isNotEmpty
                ? m.heroImageUrl
                : m.thumbnailUrl,
            releaseYear: m.releaseYear,
            genreNames: m.genreNames,
            vjNames: m.vjNames,
            durationSeconds: m.durationSeconds,
            heroFeaturedAt: m.heroFeaturedAt,
          ),
        )
        .toList(growable: false);
  }

  Future<List<StreamMovie>> _fetchLatestMovies() async {
    // Curated latest first, then pad with newest (deduped) up to the cap.
    final latest = await _getList(
      '/movies?limit=$_limit&latest=true',
      'movies',
      StreamMovie.fromJson,
    );
    if (latest.isEmpty) return latest;
    final all = await _getList(
      '/movies?limit=$_limit',
      'movies',
      StreamMovie.fromJson,
    );
    return _dedupe(latest, all, (m) => m.id).sublist(0, _limit);
  }

  /// All active VJs, uncapped (used by the menu drawer's VJ Servers section).
  Future<List<VJ>> fetchAllVJs() async {
    return _getList('/vjs?status=active&limit=50', 'vjs', VJ.fromJson);
  }

  Future<List<VJ>> _fetchVJs() async {
    return fetchAllVJs();
  }

  Future<List<Series>> _fetchLatestSeries() async {
    final latest = await _getList(
      '/series?limit=$_limit&latest=true',
      'series',
      Series.fromJson,
    );
    if (latest.isEmpty) return latest;
    final all = await _getList(
      '/series?limit=$_limit',
      'series',
      Series.fromJson,
    );
    return _dedupe(latest, all, (s) => '${s.id}').sublist(0, _limit);
  }

  Future<List<StreamMovie>> _fetchForYou() async {
    return _getList('/recommendations/for-you', 'movies', StreamMovie.fromJson);
  }

  /// All active genres, uncapped (used by the menu drawer's Genres grid).
  Future<List<Genre>> fetchAllGenres() async {
    final genres = await _getList('/genres', 'genres', Genre.fromJson);
    return genres.where((g) => g.isActive).toList(growable: false);
  }

  Future<List<Genre>> _fetchGenres() async {
    return _pickHomeGenres(await fetchAllGenres());
  }

  Future<Map<Genre, List<StreamMovie>>> _fetchGenreMovies(
    List<Genre> genres,
    List<StreamMovie> topMovies,
  ) async {
    final seenTop = <String>{for (final m in topMovies) m.id};
    final result = <Genre, List<StreamMovie>>{};

    for (final genre in genres) {
      final movies = await _getList(
        '/movies?genre_id=${genre.id}&limit=20',
        'movies',
        StreamMovie.fromJson,
      );
      // Dedupe against movies already shown higher on the page (web does this
      // via a shared seen set across genre rows + top sections).
      final unique = movies.where((m) => !seenTop.contains(m.id)).toList();
      if (unique.isNotEmpty) result[genre] = unique;
    }
    return result;
  }

  /// Orders the active genres so priority genres (action, romance) get a slot
  /// first, then fills the remaining slots from the rest, capped at 4.
  List<Genre> _pickHomeGenres(List<Genre> active) {
    if (active.isEmpty) return const [];
    final priority = <Genre>[
      for (final name in _priorityHomeGenres)
        for (final g in active)
          if (g.name.toLowerCase() == name) g,
    ];
    final rest = active.where((g) => !priority.contains(g)).toList();
    return [...priority, ...rest].sublist(0, _homeGenreLimit);
  }

  /// Reads a standard `{ "data": { "<key>": [...] } }` list response.
  Future<List<T>> _getList<T>(
    String path,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final response = await _apiClient.dio.get(path);
      final data = response.data;
      List raw = const [];
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          final list = inner[key];
          if (list is List) raw = list;
        }
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Returns [primary] followed by secondary entries whose IDs aren't already
  /// present in [primary].
  List<T> _dedupe<T>(
    List<T> primary,
    List<T> secondary,
    String Function(T) idOf,
  ) {
    final seen = <String>{for (final p in primary) idOf(p)};
    final result = [...primary];
    for (final s in secondary) {
      if (!seen.contains(idOf(s))) {
        seen.add(idOf(s));
        result.add(s);
      }
    }
    return result;
  }
}
