/// A user-created playlist as returned by the Go API (`/api/playlists`).
class Playlist {
  final String id;
  final int ownerId;
  final String ownerName;
  final String ownerAvatarUrl;
  final String title;
  final bool isPublic;
  final int viewCount;
  final int likeCount;
  final int itemCount;
  final List<String> coverUrls;
  final bool isLiked;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerAvatarUrl,
    required this.title,
    required this.isPublic,
    required this.viewCount,
    required this.likeCount,
    required this.itemCount,
    required this.coverUrls,
    required this.isLiked,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    DateTime parse(String key) {
      final raw = json[key];
      if (raw is String && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final rawCovers = json['cover_urls'];
    List<String> coverUrls = const <String>[];
    if (rawCovers is List) {
      coverUrls = rawCovers.whereType<String>().toList(growable: false);
    }

    return Playlist(
      id: json['id']?.toString() ?? '',
      ownerId: (json['owner_id'] as num?)?.toInt() ?? 0,
      ownerName: json['owner_name'] as String? ?? '',
      ownerAvatarUrl: json['owner_avatar_url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      isPublic: json['is_public'] as bool? ?? true,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      coverUrls: coverUrls,
      isLiked: json['is_liked'] as bool? ?? false,
      createdAt: parse('created_at'),
      updatedAt: parse('updated_at'),
    );
  }

  static List<Playlist> listFromJson(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(Playlist.fromJson)
          .toList(growable: false);
    }
    return const <Playlist>[];
  }
}

/// A single item within a playlist's detail response.
class PlaylistItem {
  final String itemId;
  final String contentType; // 'movie' | 'series'
  final String id;
  final String title;
  final String thumbnailUrl;
  final int releaseYear;
  final String genreNames;
  final String vjNames;
  final DateTime addedAt;

  const PlaylistItem({
    required this.itemId,
    required this.contentType,
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.releaseYear,
    required this.genreNames,
    required this.vjNames,
    required this.addedAt,
  });

  bool get isMovie => contentType == 'movie';

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    final raw = json['added_at'];
    DateTime addedAt;
    if (raw is String && raw.isNotEmpty) {
      addedAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      addedAt = DateTime.now();
    }
    return PlaylistItem(
      itemId: json['item_id']?.toString() ?? '',
      contentType: json['content_type'] as String? ?? 'movie',
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      releaseYear: (json['release_year'] as num?)?.toInt() ?? 0,
      genreNames: json['genre_names'] as String? ?? '',
      vjNames: json['vj_names'] as String? ?? '',
      addedAt: addedAt,
    );
  }

  static List<PlaylistItem> listFromJson(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(PlaylistItem.fromJson)
          .toList(growable: false);
    }
    return const <PlaylistItem>[];
  }
}
