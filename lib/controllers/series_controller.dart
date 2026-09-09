import 'package:tulabe/models/movies.dart';
import 'package:tulabe/controllers/paged_catalog_controller.dart';

/// Paged series catalog for the Series tab.
///
/// Mirrors the web `useInfiniteSeries` flow (`/api/series?page&limit=20` with
/// optional `search` / `genre_id` / `vj_id` / `status`).
class SeriesController extends PagedCatalogController<Series> {
  SeriesController()
      : super(
          apiPath: '/series',
          listKey: 'series',
          fromJson: Series.fromJson,
        );

  /// Starts a fresh series query with the given filters.
  Future<void> reload({
    String search = '',
    String? genreId,
    String? vjId,
    String status = '',
  }) {
    final extra = <String, String>{};
    if (status.isNotEmpty) extra['status'] = status;
    return super.loadFirstPage(
      search: search,
      genreId: genreId,
      vjId: vjId,
      extra: extra,
    );
  }
}