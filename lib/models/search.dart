/// A search result item (movie or series).
class SearchResult {
  final String id;
  final String type; // 'movie' | 'series'
  final String title;
  final String thumbnailUrl;
  final int releaseYear;
  final String genreNames;
  final String vjNames;
  final String status;

  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.thumbnailUrl,
    required this.releaseYear,
    required this.genreNames,
    required this.vjNames,
    required this.status,
  });

  bool get isMovie => type == 'movie';

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? 'movie',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      releaseYear: (json['release_year'] as num?)?.toInt() ?? 0,
      genreNames: json['genre_names'] as String? ?? '',
      vjNames: json['vj_names'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  static List<SearchResult> listFromJson(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(SearchResult.fromJson)
          .toList(growable: false);
    }
    return const <SearchResult>[];
  }
}

/// A lightweight search suggestion.
class Suggestion {
  final String id;
  final String type; // 'movie' | 'series'
  final String title;
  final String thumbnailUrl;
  final String vjNames;

  const Suggestion({
    required this.id,
    required this.type,
    required this.title,
    required this.thumbnailUrl,
    required this.vjNames,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? 'movie',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      vjNames: json['vj_names'] as String? ?? '',
    );
  }

  static List<Suggestion> listFromJson(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(Suggestion.fromJson)
          .toList(growable: false);
    }
    return const <Suggestion>[];
  }
}
