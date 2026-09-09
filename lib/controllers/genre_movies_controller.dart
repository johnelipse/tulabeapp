import 'package:tulabe/controllers/paged_catalog_controller.dart';
import 'package:tulabe/models/movies.dart';

/// Paged movie catalog for the Genre page — mirrors the web `/genre/[id]`
/// (`/api/movies?genre_id=&limit=20` with optional `search` / `vj_id`).
///
/// The app usually only has a genre *name* (menu drawer / home rows), so the
/// numeric genre id is resolved from `/genres` when it isn't supplied.
class GenreMoviesController extends PagedCatalogController<StreamMovie> {
  GenreMoviesController()
      : super(
          apiPath: '/movies',
          listKey: 'movies',
          fromJson: StreamMovie.fromJson,
        );

  String? _resolvedGenreId;
  String? get resolvedGenreId => _resolvedGenreId;

  /// Starts a fresh genre query. When [genreId] is empty, resolves the id
  /// from [genreName] against `/genres` first.
  Future<void> reload({
    String genreName = '',
    String? genreId,
    String search = '',
  }) async {
    String? resolved = genreId;
    if ((resolved?.isEmpty ?? true)) {
      resolved = await _resolveByName(genreName);
    }
    _resolvedGenreId = resolved;
    return super.loadFirstPage(search: search, genreId: resolved);
  }

  Future<String?> _resolveByName(String name) async {
    if (name.isEmpty) return null;
    await loadFilterOptions();
    for (final g in genres) {
      if (g.name.toLowerCase() == name.toLowerCase()) return '${g.id}';
    }
    return null;
  }
}