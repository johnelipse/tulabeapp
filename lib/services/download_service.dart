import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'download_quota_store.dart';

/// Kicks off the "Download" flow for movies and series episodes, mirroring the
/// web's `use-content-actions.ts` `useTrackDownload`:
///  1. Client-side quota gate (5 per 6 min) — same as the web localStorage.
///  2. Preflight probe `GET /movies/:id/download?quality=X` with
///     `Range: bytes=0-0` — the server answers this WITHOUT consuming its IP
///     rate-limit slot (movie_stream.go:146-168), so server-side 429/503
///     errors surface here as toasts instead of a failed system download.
///  3. Enqueue the real download through Android's DownloadManager (the
///     mobile equivalent of the browser's download manager — visible progress
///     in the notifications shade, saved to the public Downloads folder).
///
/// Download file types are MPEG-TS (`.ts`) for the common HLS-only path,
/// mirroring the server's `Content-Disposition: …_{quality}.ts`.
class DownloadService {
  static final DownloadService instance = DownloadService._();

  DownloadService._();

  static const MethodChannel _channel = MethodChannel('tulabe/downloads');

  final Dio _dio = Dio(); // no auth interceptor — downloads are public

  String _buildUrl(String movieId, String? quality) {
    final base = dotenv.env['TULABE_BASE_API'] ?? '';
    final q = (quality != null && quality.isNotEmpty) ? '?quality=$quality' : '';
    return '$base/movies/$movieId/download$q';
  }

  String _safeTitle(String title) {
    var t = title.replaceAll(RegExp(r'[/\\"?*|<>:]'), '_').trim();
    return t.isEmpty ? 'title' : t;
  }

  String _filename(String title, {String? quality, String? prefix}) {
    final base = [
      if (prefix != null && prefix.isNotEmpty) prefix,
      _safeTitle(title),
    ].where((e) => e.isNotEmpty).join(' ');
    final q = (quality != null && quality.isNotEmpty) ? '_$quality' : '';
    return '$base$q.ts';
  }

  /// Probe with `Range: bytes=0-0`. Returns null when the server is happy to
  /// serve a download, or a user-facing message for 429/503/4xx.
  Future<String?> _serverMessage(String url) async {
    try {
      final response = await _dio.get<Object?>(
        url,
        options: Options(
          headers: const {'Range': 'bytes=0-0'},
          responseType: ResponseType.bytes,
          validateStatus: (status) =>
              status == 200 ||
              status == 206 ||
              status == 400 ||
              status == 404 ||
              status == 429 ||
              status == 500 ||
              status == 503,
        ),
      );
      switch (response.statusCode) {
        case 200:
        case 206:
          return null;
        case 429:
          return 'Download limit reached. Try again in a few minutes.';
        case 503:
          return 'Too many downloads are running right now. Try again in about 5 minutes.';
        case 400:
          return "This download isn't available yet.";
        case 404:
          return "This download isn't available yet.";
        default:
          return 'Download failed — please check your connection and try again.';
      }
    } catch (_) {
      return 'Download failed — please check your connection and try again.';
    }
  }

  Future<bool> _enqueue({required String url, required String filename, required String title}) async {
    try {
      await _channel.invokeMethod<void>('enqueue', {
        'url': url,
        'filename': filename,
        'title': title,
        'description': 'Tulabe · $title',
      });
      return true;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Movie flow: quota gate → preflight → enqueue, with a quality picker left
  /// to the caller. Returns the result to toast.
  Future<DownloadStartResult> startMovie({
    required String movieId,
    required String title,
    String? quality,
  }) async {
    final quota = await DownloadQuotaStore.instance.checkAndRecord();
    if (!quota.allowed) {
      return DownloadStartResult.failed(
          'Download limit reached (5 per 6 min). Try again in '
          '${DownloadQuotaStore.formatReset(quota.resetInSeconds)}.',
          remaining: quota.remaining);
    }
    final url = _buildUrl(movieId, quality);
    final message = await _serverMessage(url);
    if (message != null) return DownloadStartResult.failed(message, remaining: quota.remaining);
    final ok = await _enqueue(url: url, filename: _filename(title, quality: quality), title: title);
    if (!ok) {
      return DownloadStartResult.failed(
          "Couldn't start the download — please check your connection and try again.",
          remaining: quota.remaining);
    }
    return DownloadStartResult.started(remaining: quota.remaining);
  }

  /// Episode flow (mirrors the web series page: one quality, no quality param).
  Future<DownloadStartResult> startEpisode({
    required String movieId,
    required String title,
    required int episodeNumber,
  }) async {
    final quota = await DownloadQuotaStore.instance.checkAndRecord();
    if (!quota.allowed) {
      return DownloadStartResult.failed(
          'Download limit reached (5 per 6 min). Try again in '
          '${DownloadQuotaStore.formatReset(quota.resetInSeconds)}.',
          remaining: quota.remaining);
    }
    final url = _buildUrl(movieId, null);
    final message = await _serverMessage(url);
    if (message != null) return DownloadStartResult.failed(message, remaining: quota.remaining);
    final ok = await _enqueue(
        url: url, filename: _filename(title, prefix: 'Ep $episodeNumber'), title: title);
    if (!ok) {
      return DownloadStartResult.failed(
          "Couldn't start the download — please check your connection and try again.",
          remaining: quota.remaining);
    }
    return DownloadStartResult.started(remaining: quota.remaining);
  }
}

class DownloadStartResult {
  final bool started;
  final String? error;
  final int remaining;

  const DownloadStartResult._({required this.started, this.error, required this.remaining});

  factory DownloadStartResult.started({required int remaining}) =>
      DownloadStartResult._(started: true, remaining: remaining);

  factory DownloadStartResult.failed(String error, {required int remaining}) =>
      DownloadStartResult._(started: false, error: error, remaining: remaining);
}