/// A genre as returned by the Go API (`/api/genres`, `/api/genres/:id`).
class Genre {
  final int id;
  final String name;
  final String slug;
  final String description;
  final bool isActive;

  const Genre({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    this.isActive = true,
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  static List<Genre> listFromJson(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(Genre.fromJson)
          .toList(growable: false);
    }
    return const <Genre>[];
  }
}
