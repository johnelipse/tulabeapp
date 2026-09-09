import 'package:flutter/foundation.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/services/api_client.dart';

/// Fetches a single movie's full record (`/movies/:id`), its cast/tags, and
/// the "more like this" list (`/movies/:id/similar`).
class MovieDetailController extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  StreamMovie? _movie;
  List<CastMember> _cast = const [];
  List<String> _tags = const [];
  List<StreamMovie> _related = const [];
  bool _loading = false;
  String? _error;

  StreamMovie? get movie => _movie;
  List<CastMember> get cast => _cast;
  List<String> get tags => _tags;
  List<StreamMovie> get related => _related;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load(String movieId) async {
    _loading = true;
    _error = null;
    _movie = null;
    _cast = const [];
    _tags = const [];
    _related = const [];
    notifyListeners();
    try {
      final detailResp = await _apiClient.dio.get('/movies/$movieId');
      final similarResp = await _apiClient.dio.get('/movies/$movieId/similar');

      final detailBody = detailResp.data;
      if (detailBody is Map<String, dynamic>) {
        final data = detailBody['data'];
        if (data is Map<String, dynamic>) {
          final rawMovie = data['movie'];
          if (rawMovie is Map<String, dynamic>) {
            _movie = StreamMovie.fromJson(rawMovie);
          }
          final rawCast = data['cast'];
          if (rawCast is List) {
            _cast = rawCast
                .whereType<Map<String, dynamic>>()
                .map(CastMember.fromJson)
                .toList(growable: false);
          }
          final rawTags = data['tags'];
          if (rawTags is List) {
            _tags = rawTags.whereType<String>().toList(growable: false);
          }
        }
      }

      final similarBody = similarResp.data;
      if (similarBody is Map<String, dynamic>) {
        final data = similarBody['data'];
        if (data is List) {
          _related = data
              .whereType<Map<String, dynamic>>()
              .map((item) {
                final raw = item['movie'];
                return (raw is Map<String, dynamic>)
                    ? StreamMovie.fromJson(raw)
                    : null;
              })
              .whereType<StreamMovie>()
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