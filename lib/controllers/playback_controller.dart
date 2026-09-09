import 'package:flutter/foundation.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/services/api_client.dart';

/// Fetches `/movies/:id/playback` for a movie or a series episode (episodes
/// are proxied by their underlying `stream_movie_id`, matching the web player).
class PlaybackController extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  bool _loading = false;
  String? _error;
  PlaybackData? _data;

  bool get loading => _loading;
  String? get error => _error;
  PlaybackData? get data => _data;
  MovieStatus get status => _data?.status ?? MovieStatus.pending;

  Future<void> load(String movieId) async {
    _loading = true;
    _error = null;
    _data = null;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get('/movies/$movieId/playback');
      final body = response.data;
      _data = PlaybackData.fromJson(
        (body is Map<String, dynamic>) ? body : const <String, dynamic>{},
      );
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }
}