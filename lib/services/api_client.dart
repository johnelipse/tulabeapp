import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Shared HTTP client for the Go API.
///
/// Auth is injected statically (not per-instance) so every controller that
/// constructs its own [ApiClient] — playlists, favorites, movies, auth — picks
/// up the current session token automatically. [AuthController] owns these
/// statics; keeping them here (instead of importing the controller) avoids a
/// controller <-> client circular dependency.
class ApiClient {
  /// Current access token, or null when signed out. Mirrors web
  /// `getToken()` (localStorage `access_token`).
  static String? accessToken;

  /// Called exactly once when an authenticated request returns 401, to
  /// refresh-and-retry (mirrors web `refreshAccessToken()`). Returns the new
  /// access token, or null when the refresh failed and the session is over.
  static Future<String?> Function()? onTokenRefresh;

  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env["TULABE_BASE_API"] ?? "",
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Access tokens expire every 15 min by design — refresh-and-retry
          // once via the still-valid refresh token before treating a 401 as a
          // real logout (mirrors the web api-client interceptor). The retry is
          // guarded so two racing 401s issue exactly one refresh call.
          final request = error.requestOptions;
          final isAuthFailure = error.response?.statusCode == 401;
          final alreadyRetried = request.extra['_authRetried'] == true;
          if (isAuthFailure && !alreadyRetried) {
            request.extra['_authRetried'] = true;
            final newToken = await onTokenRefresh?.call();
            if (newToken != null && newToken.isNotEmpty) {
              request.headers['Authorization'] = 'Bearer $newToken';
              try {
                final response = await dio.fetch(request);
                handler.resolve(response);
                return;
              } on DioException catch (_) {
                // fall through to the original error below
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }
}