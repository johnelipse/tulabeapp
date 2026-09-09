import 'cast.dart';

/// A single episode within a season.
class Episode {
  final int id;
  final int seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final int partNumber;
  final String title;
  final String description;
  final String thumbnailUrl;
  final int durationSeconds;
  final String videoUrl;
  final String streamMovieId;
  final String status;

  const Episode({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.partNumber,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.videoUrl,
    required this.streamMovieId,
    required this.status,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: (json['id'] as num?)?.toInt() ?? 0,
      seriesId: (json['series_id'] as num?)?.toInt() ?? 0,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      partNumber: (json['part_number'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      videoUrl: json['video_url'] as String? ?? '',
      streamMovieId: json['stream_movie_id']?.toString() ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

/// A season grouping of episodes.
class Season {
  final int season;
  final List<Episode> episodes;

  const Season({required this.season, required this.episodes});

  factory Season.fromJson(Map<String, dynamic> json) {
    final raw = json['episodes'];
    List<Episode> episodes = const <Episode>[];
    if (raw is List) {
      episodes = raw
          .whereType<Map<String, dynamic>>()
          .map(Episode.fromJson)
          .toList(growable: false);
    }
    return Season(
      season: (json['season'] as num?)?.toInt() ?? 0,
      episodes: episodes,
    );
  }
}

/// A series as returned by the Go API (`/api/series`, `/api/series/:id`).
class Series {
  final int id;
  final String title;
  final String slug;
  final String posterUrl;
  final String bannerUrl;
  final String description;
  final int releaseYear;
  final String languageTranslated;
  final String status;
  final String genreIds;
  final String genreNames;
  final String vjIds;
  final String vjNames;
  final int totalSeasons;
  final bool isLatest;
  final int viewCount;
  final String trailerYoutubeKey;
  final List<CastMember> cast;
  final DateTime createdAt;
  final List<Season> seasons;

  const Series({
    required this.id,
    required this.title,
    required this.slug,
    required this.posterUrl,
    required this.bannerUrl,
    required this.description,
    required this.releaseYear,
    required this.languageTranslated,
    required this.status,
    required this.genreIds,
    required this.genreNames,
    required this.vjIds,
    required this.vjNames,
    required this.totalSeasons,
    required this.isLatest,
    required this.viewCount,
    required this.trailerYoutubeKey,
    this.cast = const [],
    required this.createdAt,
    this.seasons = const [],
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    DateTime parse(String key) {
      final raw = json[key];
      if (raw is String && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return Series(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      posterUrl: json['poster_url'] as String? ?? '',
      bannerUrl: json['banner_url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      releaseYear: (json['release_year'] as num?)?.toInt() ?? 0,
      languageTranslated: json['language_translated'] as String? ?? '',
      status: json['status'] as String? ?? '',
      genreIds: json['genre_ids'] as String? ?? '',
      genreNames: json['genre_names'] as String? ?? '',
      vjIds: json['vj_ids'] as String? ?? '',
      vjNames: json['vj_names'] as String? ?? '',
      totalSeasons: (json['total_seasons'] as num?)?.toInt() ?? 0,
      isLatest: json['is_latest'] as bool? ?? false,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      trailerYoutubeKey: json['trailer_youtube_key'] as String? ?? '',
      cast: CastMember.listFromJson(json['cast']),
      createdAt: parse('created_at'),
      seasons: _parseSeasons(json['seasons']),
    );
  }

  static List<Season> _parseSeasons(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(Season.fromJson)
          .toList(growable: false);
    }
    return const <Season>[];
  }
}
