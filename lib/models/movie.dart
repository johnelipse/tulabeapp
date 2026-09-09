import 'cast.dart';

// Re-export cast types used across models.
export 'cast.dart' show CastMember;

/// Transcode/streaming pipeline status for a movie (or an episode proxy).
enum MovieStatus {
  pending,
  queued,
  processing,
  ready,
  failed;

  static MovieStatus fromJson(String? value) {
    return MovieStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => MovieStatus.pending,
    );
  }

  String toJson() => name;
}

/// A single movie/streamable title as returned by the Go API
/// (`/api/movies`, `/api/movies/:id`, hero, for-you, vjs/:id/movies, ...).
class StreamMovie {
  final String id;
  final String title;
  final String description;
  final MovieStatus status;
  final int durationSeconds;
  final String thumbnailUrl;
  final String spriteUrl;
  final bool allow1080p;
  final bool isLatest;
  final DateTime? heroFeaturedAt;
  final String heroImageUrl;
  final int viewCount;
  final int releaseYear;
  final String languageTranslated;
  final String genreIds;
  final String vjIds;
  final String genreNames;
  final String vjNames;
  final String trailerYoutubeKey;
  final List<CastMember> cast;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StreamMovie({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.durationSeconds,
    required this.thumbnailUrl,
    required this.spriteUrl,
    required this.allow1080p,
    required this.isLatest,
    this.heroFeaturedAt,
    required this.heroImageUrl,
    required this.viewCount,
    required this.releaseYear,
    required this.languageTranslated,
    required this.genreIds,
    required this.vjIds,
    required this.genreNames,
    required this.vjNames,
    required this.trailerYoutubeKey,
    this.cast = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory StreamMovie.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String key) {
      final raw = json[key];
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw);
      }
      return null;
    }

    final raw = json['cast'];

    List<CastMember> parseCast() {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(CastMember.fromJson)
            .toList();
      }
      return const <CastMember>[];
    }

    return StreamMovie(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: MovieStatus.fromJson(json['status'] as String?),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      spriteUrl: json['sprite_url'] as String? ?? '',
      allow1080p: json['allow_1080p'] as bool? ?? true,
      isLatest: json['is_latest'] as bool? ?? false,
      heroFeaturedAt: parse('hero_featured_at'),
      heroImageUrl: json['hero_image_url'] as String? ?? '',
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      releaseYear: (json['release_year'] as num?)?.toInt() ?? 0,
      languageTranslated: json['language_translated'] as String? ?? '',
      genreIds: json['genre_ids'] as String? ?? '',
      vjIds: json['vj_ids'] as String? ?? '',
      genreNames: json['genre_names'] as String? ?? '',
      vjNames: json['vj_names'] as String? ?? '',
      trailerYoutubeKey: json['trailer_youtube_key'] as String? ?? '',
      cast: parseCast(),
      createdAt: parse('created_at') ?? DateTime.now(),
      updatedAt: parse('updated_at') ?? DateTime.now(),
    );
  }

  /// Convenience list of genres from [genreNames] (comma separated).
  List<String> get genres => _splitComma(genreNames);

  /// Convenience list of VJ names from [vjNames] (comma separated).
  List<String> get vjs => _splitComma(vjNames);

  /// First VJ name, used as a card badge (mirrors the web "VJ X" pill).
  String? get firstVjName => vjs.isEmpty ? null : vjs.first;

  static List<String> _splitComma(String value) {
    if (value.isEmpty) return const <String>[];
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static List<StreamMovie> listFromJson(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(StreamMovie.fromJson)
          .toList(growable: false);
    }
    return const <StreamMovie>[];
  }
}

/// Data returned by the movie/episode `/playback` endpoint.
class PlaybackData {
  final String movieId;
  final String title;
  final String description;
  final String masterUrl;
  final String directUrl;
  final String thumbnailUrl;
  final String spriteUrl;
  final int durationSeconds;
  final bool allow1080p;
  final List<StreamMovieQuality> qualities;
  final MovieStatus status;
  final int viewCount;

  const PlaybackData({
    required this.movieId,
    required this.title,
    required this.description,
    required this.masterUrl,
    required this.directUrl,
    required this.thumbnailUrl,
    required this.spriteUrl,
    required this.durationSeconds,
    required this.allow1080p,
    required this.qualities,
    required this.status,
    required this.viewCount,
  });

  factory PlaybackData.fromJson(Map<String, dynamic> json) {
    final rawQualities = json['qualities'];
    List<StreamMovieQuality> qualities = const <StreamMovieQuality>[];
    if (rawQualities is List) {
      qualities = rawQualities
          .whereType<Map<String, dynamic>>()
          .map(StreamMovieQuality.fromJson)
          .toList(growable: false);
    }
    return PlaybackData(
      movieId: json['movie_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      masterUrl: json['master_url'] as String? ?? '',
      directUrl: json['direct_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      spriteUrl: json['sprite_url'] as String? ?? '',
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      allow1080p: json['allow_1080p'] as bool? ?? true,
      qualities: qualities,
      status: MovieStatus.fromJson(json['status'] as String?),
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A single quality variant of a streamable movie.
class StreamMovieQuality {
  final String quality;
  final String playlistUrl;

  const StreamMovieQuality({required this.quality, required this.playlistUrl});

  factory StreamMovieQuality.fromJson(Map<String, dynamic> json) {
    return StreamMovieQuality(
      quality: json['quality'] as String? ?? '',
      playlistUrl: json['playlist_url'] as String? ?? '',
    );
  }
}

/// A single homepage hero-carousel entry; may back onto a movie or a series.
class HeroItem {
  final String type; // 'movie' | 'series'
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final int releaseYear;
  final String genreNames;
  final String vjNames;
  final int durationSeconds;
  final DateTime? heroFeaturedAt;

  const HeroItem({
    required this.type,
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.releaseYear,
    required this.genreNames,
    required this.vjNames,
    required this.durationSeconds,
    this.heroFeaturedAt,
  });

  bool get isMovie => type == 'movie';

  factory HeroItem.fromJson(Map<String, dynamic> json) {
    final raw = json['hero_featured_at'];
    DateTime? featuredAt;
    if (raw is String && raw.isNotEmpty) {
      featuredAt = DateTime.tryParse(raw);
    }
    return HeroItem(
      type: json['type'] as String? ?? 'movie',
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      releaseYear: (json['release_year'] as num?)?.toInt() ?? 0,
      genreNames: json['genre_names'] as String? ?? '',
      vjNames: json['vj_names'] as String? ?? '',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      heroFeaturedAt: featuredAt,
    );
  }
}
