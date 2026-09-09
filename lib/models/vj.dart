/// A VJ (content server) as returned by the Go API (`/api/vjs`, `/api/vjs/:id`).
class VJ {
  final int id;
  final String name;
  final String slug;
  final String serverUrl;
  final String imageUrl;
  final String description;
  final bool isActive;
  final int priority;
  final DateTime createdAt;

  const VJ({
    required this.id,
    required this.name,
    required this.slug,
    required this.serverUrl,
    required this.imageUrl,
    required this.description,
    this.isActive = true,
    this.priority = 0,
    required this.createdAt,
  });

  factory VJ.fromJson(Map<String, dynamic> json) {
    final raw = json['created_at'];
    DateTime createdAt;
    if (raw is String && raw.isNotEmpty) {
      createdAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }
    return VJ(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      serverUrl: json['server_url'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
    );
  }

  static List<VJ> listFromJson(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(VJ.fromJson)
          .toList(growable: false);
    }
    return const <VJ>[];
  }
}
