import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tulabe/controllers/auth_controller.dart';
import 'package:tulabe/models/playlist.dart';
import 'package:tulabe/services/api_client.dart';

/// Fetches the Discover / My Playlists lists from the Go API.
///
/// Mirrors the web's `usePlaylists(scope)`: `GET /playlists?scope=public|mine`
/// returns a single (non-paginated) array sorted by `updated_at DESC`, so —
/// unlike movies/series — there's no infinite scroll here. Search is a
/// client-side title filter, same as the web's `filtered` memo.
class PlaylistsController extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  String _scope = 'public';
  List<Playlist> _items = const [];
  String _search = '';

  bool _isLoading = false;
  String? _error;

  String get scope => _scope;
  List<Playlist> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Whether requests will carry a bearer token — driven by [AuthController],
  /// so login/logout automatically flips "My Playlists" behavior.
  bool get signedIn => AuthController.instance.isAuthenticated;

  String get search => _search;

  /// Filtered by the client-side title search (mirrors web `filtered`).
  List<Playlist> get visible {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((p) => p.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

  /// Client-side search filter — re-lists instantly, no network round trip.
  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    notifyListeners();
  }

  /// Loads the given scope. "mine" without a signed-in user is skipped
  /// entirely (the UI shows the sign-in prompt instead of a 401).
  Future<void> load({String scope = 'public'}) async {
    _scope = scope;
    _items = const [];
    _error = null;

    if (scope == 'mine' && !signedIn) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      final response =
          await _apiClient.dio.get('/playlists', queryParameters: {'scope': scope});
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          _items = Playlist.listFromJson(data['playlists']);
        }
      }
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => load(scope: _scope);

  /// Creates a playlist (public by default — mirrors the web's Create
  /// Playlist bar). Returns a human-readable error message on failure so the
  /// UI can surface *why* the create failed, or null on success.
  Future<String?> create(String title) async {
    final t = title.trim();
    if (t.isEmpty) return 'Name is required';
    try {
      await _apiClient.dio.post('/playlists', data: {'title': t});
      return null;
    } catch (e) {
      final err = _messageFrom(e);
      return err.isNotEmpty ? err : 'Failed to create playlist';
    }
  }

  String _messageFrom(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return "Couldn't reach the server. Check your connection.";
      }
      if (e.type == DioExceptionType.connectionError) {
        return "Couldn't reach the server. Check your connection.";
      }
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is String && err.isNotEmpty) return err;
        final msg = data['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
      if (e.response?.statusCode != null) {
        return 'Server error (${e.response!.statusCode})';
      }
    }
    return '';
  }
}