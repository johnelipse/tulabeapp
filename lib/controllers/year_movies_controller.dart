import 'package:tulabe/controllers/paged_catalog_controller.dart';
import 'package:tulabe/models/movies.dart';

/// Paged movie catalog for the year browse screen.
///
/// Mirrors the web "Browse by Year" chip → `/movies?year=X` flow: an
/// infinite-scroll grid of `/api/movies` filtered to one release year
/// (optionally refined by a server-side title search).
class YearMoviesController extends PagedCatalogController<StreamMovie> {
  YearMoviesController()
      : super(
          apiPath: '/movies',
          listKey: 'movies',
          fromJson: StreamMovie.fromJson,
        );

  /// Starts a fresh query restricted to [year] with an optional [search].
  Future<void> reload({required String year, String search = ''}) {
    final extra = <String, String>{};
    if (year.isNotEmpty) extra['year'] = year;
    return super.loadFirstPage(search: search, extra: extra);
  }
}