/// A category as returned by the Go API (`/api/categories`, `/api/categories/:id`).
class Category {
  final int id;
  final String name;
  final String slug;
  final String description;
  final bool isActive;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  static List<Category> listFromJson(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList(growable: false);
    }
    return const <Category>[];
  }
}
