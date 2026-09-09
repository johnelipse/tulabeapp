/// The authenticated user as returned by the Go API (`/auth/me`,
/// `/auth/login`, `/auth/register`, ...). Mirrors the web's `User` type.
class TulabeUser {
  final int id;
  final String name;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String provider;
  final bool isActive;
  final String? avatarUrl;

  const TulabeUser({
    required this.id,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.provider,
    required this.isActive,
    this.avatarUrl,
  });

  factory TulabeUser.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar_url'] as String?;
    return TulabeUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'USER',
      provider: json['provider'] as String? ?? 'local',
      isActive: json['is_active'] as bool? ?? true,
      avatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
    );
  }

  /// Single-letter avatar initial, e.g. "J" for "John".
  String get initial {
    final trimmed = (firstName.isNotEmpty ? firstName : name).trim();
    return trimmed.isEmpty ? 'T' : trimmed[0].toUpperCase();
  }
}