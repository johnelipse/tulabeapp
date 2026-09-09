import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A saved movie/series entry, mirroring the web `FavoriteEntry`
/// (`apps/web/store/favorites.ts`) persisted in localStorage.
class FavoriteEntry {
  final String id;
  final String type; // 'movie' | 'series'
  final String title;
  final String thumbnailUrl;
  final int releaseYear;
  final int savedAt;

  const FavoriteEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.thumbnailUrl,
    required this.releaseYear,
    required this.savedAt,
  });

  bool get isSeries => type == 'series';

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'thumbnail_url': thumbnailUrl,
        'release_year': releaseYear,
        'saved_at': savedAt,
      };

  factory FavoriteEntry.fromJson(Map<String, dynamic> json) {
    return FavoriteEntry(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? 'movie',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      releaseYear: (json['release_year'] as num?)?.toInt() ?? 0,
      savedAt: (json['saved_at'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Local favorites store — same behaviour as the web's Zustand/localStorage
/// store. No login required (the API favorites endpoints need auth), so the
/// list lives on-device and persists via `shared_preferences`.
class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();

  static final FavoritesStore instance = FavoritesStore._();

  static const String _prefsKey = 'tulabe_favorites';

  final List<FavoriteEntry> _items = <FavoriteEntry>[];
  bool _loaded = false;

  List<FavoriteEntry> get items => List.unmodifiable(_items);

  /// Loads persisted favorites once (idempotent).
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items
            ..clear()
            ..addAll(decoded
                .whereType<Map<String, dynamic>>()
                .map(FavoriteEntry.fromJson));
        }
      }
    } catch (_) {
      // Corrupt/absent store — start empty.
    }
    _loaded = true;
    notifyListeners();
  }

  bool isFavorited(String id, String type) =>
      _items.any((e) => e.id == id && e.type == type);

  void add({
    required String id,
    required String type,
    required String title,
    String thumbnailUrl = '',
    int releaseYear = 0,
  }) {
    if (isFavorited(id, type)) return;
    _items.insert(
      0,
      FavoriteEntry(
        id: id,
        type: type,
        title: title,
        thumbnailUrl: thumbnailUrl,
        releaseYear: releaseYear,
        savedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    notifyListeners();
    _persist();
  }

  void remove(String id, String type) {
    _items.removeWhere((e) => e.id == id && e.type == type);
    notifyListeners();
    _persist();
  }

  void toggle({
    required String id,
    required String type,
    required String title,
    String thumbnailUrl = '',
    int releaseYear = 0,
  }) {
    if (isFavorited(id, type)) {
      remove(id, type);
    } else {
      add(
        id: id,
        type: type,
        title: title,
        thumbnailUrl: thumbnailUrl,
        releaseYear: releaseYear,
      );
    }
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // Non-fatal: in-memory state still works for this session.
    }
  }
}