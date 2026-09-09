/// The comment author ("user" inside a [Comment]) — mirrors the web
/// `CommentAuthor` and the Go `commentAuthor` response type.
class CommentAuthor {
  final int id;
  final String name;
  final String avatarUrl;

  const CommentAuthor({required this.id, required this.name, this.avatarUrl = ''});

  factory CommentAuthor.fromJson(Map<String, dynamic> json) {
    return CommentAuthor(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Tulabe User',
      avatarUrl: json['avatar_url'] as String? ?? '',
    );
  }

  /// Single-letter avatar initial (matches the web's `charAt(0)`).
  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }
}

/// A single comment on a movie or series detail page — mirrors the web
/// `Comment` type. Replies are one level deep (the Go API flattens
/// replies-to-replies into the top-level thread).
class Comment {
  final int id;
  final String contentType;
  final String contentId;
  final int? parentId;
  final String body;
  final DateTime createdAt;
  final CommentAuthor user;
  final List<Comment> replies;

  /// True for one-level replies (they carry a [parentId]).
  bool get isReply => parentId != null;

  const Comment({
    required this.id,
    required this.contentType,
    required this.contentId,
    this.parentId,
    required this.body,
    required this.createdAt,
    required this.user,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['replies'];
    return Comment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      contentType: json['content_type'] as String? ?? '',
      contentId: json['content_id'] as String? ?? '',
      parentId: (json['parent_id'] as num?)?.toInt(),
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      user: json['user'] is Map<String, dynamic>
          ? CommentAuthor.fromJson(json['user'] as Map<String, dynamic>)
          : const CommentAuthor(id: 0, name: 'Tulabe User'),
      replies: rawReplies is List
          ? rawReplies
              .whereType<Map<String, dynamic>>()
              .map(Comment.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  /// Copy with a new replies list (used when adding/removing a reply).
  Comment withReplies(List<Comment> replies) => Comment(
        id: id,
        contentType: contentType,
        contentId: contentId,
        parentId: parentId,
        body: body,
        createdAt: createdAt,
        user: user,
        replies: replies,
      );
}