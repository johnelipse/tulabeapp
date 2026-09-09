import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tulabe/models/user.dart';
import 'package:tulabe/services/api_client.dart';

/// Session/account state, mirroring the web's `lib/auth.ts`,
/// `context/user-context.tsx`, `hooks/use-auth.ts` and `token-refresh.ts`.
///
/// - Access tokens are short-lived (15 min) and refreshed via `/auth/refresh`
///   when a 401 comes back (the [ApiClient] interceptor calls [refresh]).
/// - Refresh tokens last a week; a failed refresh means the session is over and
///   both tokens are cleared.
/// - Tokens and the cached user are restored on launch via [ensureLoaded].
class AuthController extends ChangeNotifier {
  static final AuthController instance = AuthController._();

  static const _accessKey = 'tulabe_access_token';
  static const _refreshKey = 'tulabe_refresh_token';

  final ApiClient _api = ApiClient();

  TulabeUser? _user;
  bool _loading = false;
  String? _error;

  TulabeUser? get user => _user;

  /// The cached user's display name (falls back to email if unknown).
  String get displayName {
    final u = _user;
    if (u == null) return '';
    final full = '${u.firstName} ${u.lastName}'.trim();
    return full.isNotEmpty ? full : u.email;
  }

  bool get loading => _loading;
  String? get error => _error;

  /// Whether requests will carry a bearer token (web `isAuthenticated()`).
  bool get isAuthenticated {
    final token = ApiClient.accessToken;
    return token != null && token.isNotEmpty;
  }

  AuthController._() {
    ApiClient.onTokenRefresh = refresh;
  }

  /// Restores a persisted session on app start: reloads the bearer token and
  /// re-fetches the user via `/auth/me`. A 401 here is handled by the
  /// interceptor (refresh once, otherwise clear the session).
  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_accessKey);
    final refreshToken = prefs.getString(_refreshKey);
    if (access == null || access.isEmpty || refreshToken == null || refreshToken.isEmpty) {
      return;
    }

    ApiClient.accessToken = access;
    _user = null;
    notifyListeners();

    try {
      final response = await _api.dio.get('/auth/me');
      _user = _parseUser(response.data);
    } catch (_) {
      // Interceptor already attempted a refresh; if it failed, the stored
      // tokens were cleared and accessToken is null again (signed out).
      if (isAuthenticated) {
        _user = null;
        await _clearStored();
      }
    }
    notifyListeners();
  }

  /// POST /auth/login. Returns true on success (tokens persisted + user set).
  Future<bool> login(String email, String password) => _guard(() async {
        final response = await _api.dio.post(
          '/auth/login',
          data: {'email': email.trim(), 'password': password},
        );
        await _applyAuthResponse(response.data);
      });

  /// POST /auth/register. Returns true on success.
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) =>
      _guard(() async {
        final response = await _api.dio.post(
          '/auth/register',
          data: {
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'email': email.trim(),
            'password': password,
            'password_confirmation': passwordConfirmation,
          },
        );
        await _applyAuthResponse(response.data);
      });

  /// Clears the session locally (the Go logout endpoint is stateless — mirrors
  /// web `clearTokens()` + refetch).
  Future<void> logout() async {
    await _clearStored();
    ApiClient.accessToken = null;
    _user = null;
    _error = null;
    notifyListeners();
  }

  /// POST /auth/refresh — rotates both tokens. Returns the new access token or
  /// null when the refresh failed (session over). Single-flight handled by the
  /// interceptor, not here.
  Future<String?> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_refreshKey);
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await _api.dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final upstream = (response.data as Map<String, dynamic>?)?['data'];
      final tokens = upstream is Map<String, dynamic> ? upstream['tokens'] : null;
      final access = tokens is Map<String, dynamic> ? tokens['access_token'] as String? : null;
      final newRefresh = tokens is Map<String, dynamic> ? tokens['refresh_token'] as String? : null;
      if (access == null || access.isEmpty || newRefresh == null || newRefresh.isEmpty) {
        return null;
      }
      await prefs.setString(_accessKey, access);
      await prefs.setString(_refreshKey, newRefresh);
      ApiClient.accessToken = access;
      return access;
    } catch (_) {
      return null;
    }
  }

  /// POST /auth/forgot-password. The API always returns the same generic
  /// message, so success means "email posted"; failures are network-level.
  Future<bool> forgotPassword(String email) => _guard(() async {
        await _api.dio.post(
          '/auth/forgot-password',
          data: {'email': email.trim()},
        );
      });

  /// POST /auth/reset-password. Returns true when a new password was set.
  Future<bool> resetPassword(String token, String password) => _guard(() async {
        await _api.dio.post(
          '/auth/reset-password',
          data: {'token': token.trim(), 'password': password},
        );
      });

  /// PATCH /auth/me — updates the current user's own profile fields.
  Future<bool> updateProfile({required String firstName, required String lastName}) =>
      _guard(() async {
        final response = await _api.dio.patch(
          '/auth/me',
          data: {'first_name': firstName.trim(), 'last_name': lastName.trim()},
        );
        _user = _parseUser(response.data);
      });

  /// POST /auth/change-password.
  Future<bool> changePassword({required String currentPassword, required String newPassword}) =>
      _guard(() async {
        await _api.dio.post(
          '/auth/change-password',
          data: {'current_password': currentPassword, 'new_password': newPassword},
        );
      });

  Future<bool> _guard(Future<void> Function() action) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on DioException catch (e) {
      _error = _messageFrom(e);
      return false;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _applyAuthResponse(Object? body) async {
    final data = body is Map<String, dynamic> ? body['data'] : null;
    final tokens = data is Map<String, dynamic> ? data['tokens'] : null;
    final access = tokens is Map<String, dynamic> ? tokens['access_token'] as String? : null;
    final refreshToken = tokens is Map<String, dynamic> ? tokens['refresh_token'] as String? : null;
    if (access == null || access.isEmpty || refreshToken == null || refreshToken.isEmpty) {
      throw const FormatException('Response did not include tokens');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refreshToken);
    ApiClient.accessToken = access;
    _user = _parseUser(body);
    _error = null;
  }

  TulabeUser? _parseUser(Object? body) {
    final data = body is Map<String, dynamic> ? body['data'] : null;
    final userJson = data is Map<String, dynamic> ? data['user'] : null;
    return userJson is Map<String, dynamic> ? TulabeUser.fromJson(userJson) : null;
  }

  Future<void> _clearStored() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final err = data['error'];
      if (err is String && err.isNotEmpty) return err;
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return 'Something went wrong. Please try again.';
  }
}