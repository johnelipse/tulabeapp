import 'package:flutter/foundation.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/services/api_client.dart';

/// Fetches a single series (`/series/:id`), including seasons/episodes and
/// cast, plus the "more like this" list (`/series/:id/similar`).
class SeriesDetailController extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  Series? _series;
  List<Season> _seasons = const [];
  List<CastMember> _cast = const [];
  List<String> _tags = const [];
  List<Series> _related = const [];
  bool _loading = false;
  String? _error;

  Series? get series => _series;
  List<Season> get seasons => _seasons;
  List<CastMember> get cast => _cast;
  List<String> get tags => _tags;
  List<Series> get related => _related;
  bool get loading => _loading;
  String? get error => _error;

  /// All episodes across every season, in order (used for "Play S1E1" and
  /// next-episode handling).
  List<Episode> get allEpisodes =>
      [for (final s in _seasons) ...s.episodes];

  Future<void> load(String seriesId) async {
    _loading = true;
    _error = null;
    _series = null;
    _seasons = const [];
    _cast = const [];
    _tags = const [];
    _related = const [];
    notifyListeners();
    try {
      final detailResp = await _apiClient.dio.get('/series/$seriesId');
      final similarResp = await _apiClient.dio.get('/series/$seriesId/similar');

      final detailBody = detailResp.data;
      if (detailBody is Map<String, dynamic>) {
        final data = detailBody['data'];
        if (data is Map<String, dynamic>) {
          final rawSeries = data['series'];
          if (rawSeries is Map<String, dynamic>) {
            _series = Series.fromJson(rawSeries);
          }
          final rawSeasons = data['seasons'];
          if (rawSeasons is List) {
            final seasons = rawSeasons
                .whereType<Map<String, dynamic>>()
                .map(Season.fromJson)
                .toList(growable: false);
            if (seasons.isNotEmpty) _seasons = seasons;
          }
          final rawCast = data['cast'];
          if (rawCast is List) {
            final cast = rawCast
                .whereType<Map<String, dynamic>>()
                .map(CastMember.fromJson)
                .toList(growable: false);
            if (cast.isNotEmpty) _cast = cast;
          }
          final rawTags = data['tags'];
          if (rawTags is List) {
            _tags = rawTags.whereType<String>().toList(growable: false);
          }
        }
      }
      if (_seasons.isEmpty) _seasons = _series?.seasons ?? const [];
      if (_cast.isEmpty) _cast = _series?.cast ?? const [];

      final similarBody = similarResp.data;
      if (similarBody is Map<String, dynamic>) {
        final data = similarBody['data'];
        if (data is List) {
          _related = data
              .whereType<Map<String, dynamic>>()
              .map((item) {
                final raw = item['series'];
                return (raw is Map<String, dynamic>)
                    ? Series.fromJson(raw)
                    : null;
              })
              .whereType<Series>()
              .toList(growable: false);
        }
      }
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }
}