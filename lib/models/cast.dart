/// A cast member enriched via TMDb for a movie or series.
class CastMember {
  final String name;
  final String characterName;
  final String photoUrl;

  const CastMember({
    required this.name,
    required this.characterName,
    required this.photoUrl,
  });

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      name: json['name'] as String? ?? '',
      characterName: json['character_name'] as String? ?? '',
      photoUrl: json['photo_url'] as String? ?? '',
    );
  }

  static List<CastMember> listFromJson(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(CastMember.fromJson)
          .toList(growable: false);
    }
    return const <CastMember>[];
  }
}
