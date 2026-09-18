import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/screens/movie_detail_screen.dart';
import 'package:tulabe/screens/series_detail_screen.dart';
import 'package:tulabe/theme/app_colors.dart';

/// FCM push signalled when a new title drops on Tulabe.
///
/// Talks to the small standalone relay (`relay/` in this repo) —
/// `POST /api/push/subscribe` with a Firebase device token — which then
/// delivers broadcasts through Firebase Cloud Messaging. This keeps all
/// notification machinery outside the web repo. Foreground messages surface
/// as an in-app banner; background/terminated messages use the system
/// notification and tapping one deep-links into the movie/series detail
/// screen via `data.url`.
class PushController extends ChangeNotifier {
  PushController._();

  static final PushController instance = PushController._();

  /// Injected into the app's MaterialApp so tap-to-open can navigate from
  /// outside the widget tree (cold start + background tap).
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static const _prefsKey = 'tulabe_push_enabled';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  Dio? _relay;

  bool _enabled = false;
  bool _busy = false;
  bool _prompted = false;
  String? _error;
  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenSub;

  bool get enabled => _enabled;
  bool get busy => _busy;
  String? get error => _error;

  /// Must be called once after `Firebase.initializeApp()` (see main.dart).
  /// Restores a previously-enabled toggle, re-registers a rotated token, and
  /// wires the message listeners. Never prompts for permission on its own —
  /// that only happens when the user turns notifications on (or already had
  /// them on).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefsKey) ?? false;

    // Point at the push relay (see .env: PUSH_RELAY_URL / PUSH_RELAY_KEY).
    final relayBase = dotenv.env['PUSH_RELAY_URL'] ?? '';
    final relayKey = dotenv.env['PUSH_RELAY_KEY'] ?? '';
    _relay = Dio(BaseOptions(
      baseUrl: relayBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {if (relayKey.isNotEmpty) 'X-Relay-Key': relayKey},
    ));

    // Token rotation: Firebase can hand the app a new token at any time; keep
    // the backend row for this device fresh.
    _messaging.onTokenRefresh.listen(_register);

    _onMessageSub = FirebaseMessaging.onMessage.listen(_onForeground);
    _onOpenSub = FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) _openMessage(initial);

    if (_enabled) {
      // Session restored: re-affirm the registration (idempotent upsert).
      unawaited(_enable());
    }
  }

  /// Whether the app should surface the "allow notifications" prompt on the
  /// next open: notifications are not already on and the OS permission has not
  /// been granted yet. Idempotent per process — after the user answers, it
  /// won't nag again within the same session.
  Future<bool> shouldShowPermissionPrompt() async {
    if (_prompted) return false;
    if (_enabled) return false;
    try {
      final settings = await _messaging.getNotificationSettings();
      final status = settings.authorizationStatus;
      return status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Marks the permission prompt as answered for this process so it doesn't
  /// pop up repeatedly while the app is open.
  void markPermissionPromptSeen() => _prompted = true;

  /// Turns the notification toggle on/off and pushes the change to the API.
  /// Returns the new enabled state (false when permission is denied/revoked).
  Future<bool> setEnabled(bool value) async {
    if (_busy) return _enabled;
    if (value) {
      final ok = await _enable();
      if (ok) _persist(true);
      return ok;
    }
    await _disable();
    _persist(false);
    return false;
  }

  Future<bool> _enable() async {
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) {
        _error = 'Notification permission was denied. Enable it in system settings.';
        _busy = false;
        notifyListeners();
        return false;
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        _error = 'Could not get a push token.';
        _busy = false;
        notifyListeners();
        return false;
      }
      await _subscribe(token);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _disable() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          await _relay?.post('/api/push/unsubscribe', data: {'token': token});
        } catch (_) {
          // The relay row may already be gone; deleting the local token is
          // still correct.
        }
      }
      await _messaging.deleteToken();
    } catch (e) {
      _error = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Registers this device's FCM token with the relay (idempotent upsert).
  Future<void> _subscribe(String token) async {
    if (_relay == null) return;
    await _relay!.post('/api/push/subscribe', data: {
      'platform': 'android',
      'token': token,
    });
  }

  Future<void> _register(String token) async {
    try {
      await _subscribe(token);
    } catch (_) {
      // Best-effort; next init or token refresh retries.
    }
  }

  Future<void> _persist(bool value) async {
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  /// Foreground message: show an in-app banner (system notifications are not
  /// displayed while the app is open). Tapping it opens the content.
  void _onForeground(RemoteMessage message) {
    final title = message.notification?.title ?? 'Tulabe';
    final body = message.notification?.body ?? '';
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          body.isEmpty ? title : '$title\n$body',
          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF161018),
        action: body.isEmpty
            ? null
            : SnackBarAction(
                label: 'VIEW',
                textColor: AppColors.primary,
                onPressed: () => _openMessage(message),
              ),
      ));
  }

  /// Tap on a system notification (background or cold-start). Opens the
  /// movie/series detail screen when `data.url` carries a known link.
  void _openMessage(RemoteMessage message) {
    final url = message.data['url'] ?? '';
    final match = RegExp(r'/(movie|series)/([A-Za-z0-9-]+)').firstMatch(url);
    if (match == null) return;

    final type = match.group(1);
    final id = match.group(2);
    if (type == null || id == null) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pushDetail(type, id));
      return;
    }
    _pushDetail(type, id);
  }

  void _pushDetail(String type, String id) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    // Don't stack the same screen when the user taps the banner twice.
    navigator.push(
      MaterialPageRoute(
        builder: (_) => type == 'series'
            ? SeriesDetailScreen(
                series: Movie(title: '', subtitle: null, imageUrl: '', id: id))
            : MovieDetailScreen(
                movie: Movie(title: '', subtitle: null, imageUrl: '', id: id)),
      ),
    );
  }

  @override
  void dispose() {
    _onMessageSub?.cancel();
    _onOpenSub?.cancel();
    super.dispose();
  }
}

/// Runs in its own isolate when the app is backgrounded. Our sends carry a
/// `notification` payload, so the system displays them without this handler;
/// it exists so a future data-only message still wakes cleanly.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {}