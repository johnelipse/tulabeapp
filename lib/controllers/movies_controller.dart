import 'package:tulabe/models/movies.dart';
import 'package:tulabe/controllers/paged_catalog_controller.dart';

/// Paged movie catalog for the Movies tab.
///
/// Mirrors the web `useInfiniteMovies` flow (`/api/movies?page&limit=20` with
/// optional `search` / `genre_id` / `vj_id` / `latest` / `year`).
class MoviesController extends PagedCatalogController<StreamMovie> {
  MoviesController()
      : super(
          apiPath: '/movies',
          listKey: 'movies',
          fromJson: StreamMovie.fromJson,
        );

  /// Starts a fresh movies query with the given filters.
  Future<void> reload({
    String search = '',
    String? genreId,
    String? vjId,
    bool latest = false,
    String? year,
  }) {
    final extra = <String, String>{};
    if (latest) extra['latest'] = 'true';
    if (year != null && year.isNotEmpty) extra['year'] = year;
    return super.loadFirstPage(
      search: search,
      genreId: genreId,
      vjId: vjId,
      extra: extra,
    );
  }
}