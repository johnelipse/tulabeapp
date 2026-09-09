import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A watched-position entry, mirroring the web `WatchProgressEntry`
/// (`apps/web/store/watch-progress.ts`) persisted in localStorage.
class WatchProgressEntry {
  /// Unique key — the stream movie id (same value [InlinePlayer.movieId]
  /// uses). For series episodes this is the episode's `stream_movie_id`, the
  /// underlying movie the player actually loads.
  final String movieId;
  final String title;

  /// Image shown on the continue-watching card (series banner or movie thumb).
  final String thumbnailUrl;

  /// Seconds of completed playback, and the stream's total length.
  final double currentTime;
  final double duration;

  /// Set when this entry belongs to a series (episode of `seriesId`) so the
  /// resume tap can reopen the series page instead of a movie page.
  final String? seriesId;

  final int lastWatched;

  const WatchProgressEntry({
    required this.movieId,
    required this.title,
    required this.thumbnailUrl,
    required this.currentTime,
    required this.duration,
    this.seriesId,
    required this.lastWatched,
  });

  Map<String, dynamic> toJson() => {
        'movie_id': movieId,
        'title': title,
        'thumbnail_url': thumbnailUrl,
        'current_time': currentTime,
        'duration': duration,
        'series_id': seriesId,
        'last_watched': lastWatched,
      };

  factory WatchProgressEntry.fromJson(Map<String, dynamic> json) {
    return WatchProgressEntry(
      movieId: json['movie_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      currentTime: (json['current_time'] as num?)?.toDouble() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      seriesId: json['series_id']?.toString(),
      lastWatched: (json['last_watched'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Local watch-progress store — same behaviour as the web's Zustand store.
/// Position is captured by the inline player and re-applied on resume from
/// the "Continue Watching" row on the home screen.
class WatchProgressStore extends ChangeNotifier {
  WatchProgressStore._();

  static final WatchProgressStore instance = WatchProgressStore._();

  static const String _prefsKey = 'tulabe_watch_progress';

  static const int _maxEntries = 20;
  static const double _minProgress = 0.05;
  static const double _maxProgress = 0.92;
  static const int _expiryMs = 7 * 24 * 60 * 60 * 1000; // 1 week

  final List<WatchProgressEntry> _entries = <WatchProgressEntry>[];
  bool _loaded = false;

  /// Loads persisted progress once (idempotent).
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _entries
            ..clear()
            ..addAll(decoded
                .whereType<Map<String, dynamic>>()
                .map(WatchProgressEntry.fromJson));
        }
      }
    } catch (_) {
      // Corrupt/absent store — start empty.
    }
    _loaded = true;
    notifyListeners();
  }

  /// Mirrors the web `saveProgress`: entries past 92% are dropped, entries
  /// under 5% are ignored, series keep only their latest episode, and the
  /// whole list expires after a week and caps at 20 entries.
  void saveProgress({
    required String movieId,
    required String title,
    String thumbnailUrl = '',
    required double currentTime,
    required double duration,
    String? seriesId,
  }) {
    if (movieId.isEmpty) return;
    final progress = duration > 0 ? currentTime / duration : 0.0;
    if (progress > _maxProgress) {
      _entries.removeWhere((e) => e.movieId == movieId);
      notifyListeners();
      _persist();
      return;
    }
    if (progress < _minProgress) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - _expiryMs;
    final filtered = _entries.where((e) {
      // Remove the exact same movieId entry (update).
      if (e.movieId == movieId) return false;
      // For series, keep only the latest episode — remove any previous
      // entries for the same series so only the most recent shows up.
      if (seriesId != null && seriesId.isNotEmpty && e.seriesId == seriesId) {
        return false;
      }
      return e.lastWatched > cutoff;
    }).toList(growable: false);
    final updated = <WatchProgressEntry>[
      WatchProgressEntry(
        movieId: movieId,
        title: title,
        thumbnailUrl: thumbnailUrl,
        currentTime: currentTime,
        duration: duration,
        seriesId: seriesId,
        lastWatched: now,
      ),
      ...filtered,
    ].take(_maxEntries).toList(growable: false);
    _entries
      ..clear()
      ..addAll(updated);
    notifyListeners();
    _persist();
  }

  void removeEntry(String movieId) {
    _entries.removeWhere((e) => e.movieId == movieId);
    notifyListeners();
    _persist();
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
    _persist();
  }

  /// Entries in the "in-progress" band (5%–92%), unexpired, newest first.
  List<WatchProgressEntry> get inProgress {
    final cutoff = DateTime.now().millisecondsSinceEpoch - _expiryMs;
    final list = _entries.where((e) {
      final p = e.duration > 0 ? e.currentTime / e.duration : 0.0;
      return p >= _minProgress && p <= _maxProgress && e.lastWatched > cutoff;
    }).toList(growable: false);
    list.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
    return list;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_entries.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // Non-fatal: in-memory state still works for this session.
    }
  }
}