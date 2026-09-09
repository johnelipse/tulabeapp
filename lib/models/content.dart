/// A saved/favorited item.
class FavoriteItem {
  final int id;
  final String contentType; // 'movie' | 'series'
  final String contentId;
  final String title;
  final String thumbnailUrl;
  final int releaseYear;
  final DateTime createdAt;

  const FavoriteItem({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.title,
    required this.thumbnailUrl,
    required this.releaseYear,
    required this.createdAt,
  });

  bool get isMovie => contentType == 'movie';

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    final raw = json['created_at'];
    DateTime createdAt;
    if (raw is String && raw.isNotEmpty) {
      createdAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }
    return FavoriteItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      contentType: json['content_type'] as String? ?? 'movie',
      contentId: json['content_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      releaseYear: (json['release_year'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
    );
  }

  static List<FavoriteItem> listFromJson(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(FavoriteItem.fromJson)
          .toList(growable: false);
    }
    return const <FavoriteItem>[];
  }
}

/// Rating summary for a movie/series.
class RatingInfo {
  final double averageRating;
  final int totalRatings;
  final int yourScore;

  const RatingInfo({
    required this.averageRating,
    required this.totalRatings,
    required this.yourScore,
  });

  factory RatingInfo.fromJson(Map<String, dynamic> json) {
    return RatingInfo(
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalRatings: (json['total_ratings'] as num?)?.toInt() ?? 0,
      yourScore: (json['your_score'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Download quota/status for a movie.
class DownloadStatus {
  final bool allowed;
  final int used;
  final int limit;
  final int remaining;
  final int resetIn;
  final String? reason;

  const DownloadStatus({
    required this.allowed,
    required this.used,
    required this.limit,
    required this.remaining,
    required this.resetIn,
    this.reason,
  });

  factory DownloadStatus.fromJson(Map<String, dynamic> json) {
    return DownloadStatus(
      allowed: json['allowed'] as bool? ?? false,
      used: (json['used'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      resetIn: (json['reset_in'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
    );
  }
}
