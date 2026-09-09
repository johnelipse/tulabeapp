import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tulabe/controllers/auth_controller.dart';
import 'package:tulabe/models/comment.dart';
import 'package:tulabe/models/user.dart';
import 'package:tulabe/services/api_client.dart';

/// Comments for one movie/series detail page, mirroring the web's
/// `use-comments.ts`:
/// - `GET /comments?content_type&content_id&limit&offset` returns top-level
///   comments (newest first) with their replies nested, plus a total.
/// - `POST /comments` (auth required) creates a comment or a one-level reply
///   (`parent_id`, only ever on a top-level comment).
/// - `DELETE /comments/:id` (owner or admin) removes a comment and its replies.
///
/// [ApiClient] injects the bearer token automatically, so signed-in users can
/// post/delete; anonymous users only read.
class CommentsController extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  String _contentType = 'movie';
  String _contentId = '';
  List<Comment> _comments = const [];
  int _total = 0;
  int _limit = 5;
  bool _loading = false;
  bool _submitting = false;
  String? _error;
  String _sortMode = 'newest'; // 'newest' | 'oldest'

  String get contentType => _contentType;
  String get contentId => _contentId;
  List<Comment> get comments {
    final list = [..._comments];
    list.sort((a, b) => _sortMode == 'newest'
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  int get total => _total;
  bool get loading => _loading;
  bool get submitting => _submitting;
  String? get error => _error;
  String get sortMode => _sortMode;
  bool get canShowMore => _total > _comments.length;

  bool get signedIn => AuthController.instance.isAuthenticated;

  TulabeUser? get currentUser => AuthController.instance.user;

  /// Delete permission — own comment or an ADMIN (mirrors web `canDelete`).
  bool canDelete(Comment c) {
    final user = AuthController.instance.user;
    if (user == null) return false;
    return user.id == c.user.id || user.role == 'ADMIN';
  }

  void setSortMode(String mode) {
    if (mode == _sortMode) return;
    _sortMode = mode;
    notifyListeners();
  }

  /// Loads (or re-loads) the top-level comments. [limit] grows on "See all";
  /// [reset] clears the cached list first.
  Future<void> load({
    required String contentType,
    required String contentId,
    int limit = 5,
    bool reset = true,
  }) async {
    _contentType = contentType;
    _contentId = contentId;
    _limit = limit;
    _error = null;
    if (reset) {
      _comments = const [];
      _total = 0;
    }
    _loading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get(
        '/comments',
        queryParameters: {
          'content_type': contentType,
          'content_id': contentId,
          'limit': limit,
          'offset': 0,
        },
      );
      final data = response.data is Map<String, dynamic> ? response.data['data'] : null;
      if (data is Map<String, dynamic>) {
        final raw = data['comments'];
        if (raw is List) {
          _comments = raw
              .whereType<Map<String, dynamic>>()
              .map(Comment.fromJson)
              .toList(growable: false);
        }
        final pagination = data['pagination'];
        if (pagination is Map<String, dynamic>) {
          _total = (pagination['total'] as num?)?.toInt() ?? _comments.length;
        }
      }
    } on DioException catch (e) {
      _error = _errorMessage(e, "Couldn't load comments");
    } catch (_) {
      _error = "Couldn't load comments";
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMore() => load(
        contentType: _contentType,
        contentId: _contentId,
        limit: _limit + 10,
        reset: false,
      );

  /// POST /comments. Returns true on success (the created comment is inserted
  /// at the head of the list or into its parent's replies).
  Future<bool> add({required String body, int? parentId}) async {
    _error = null;
    _submitting = true;
    notifyListeners();
    try {
      final response = await _apiClient.dio.post('/comments', data: {
        'content_type': _contentType,
        'content_id': _contentId,
        'body': body,
        'parent_id': ?parentId,
      });
      final created = _parseComment(response.data);
      if (created == null) {
        _error = "Couldn't post your comment. Please try again.";
        return false;
      }
      if (parentId == null) {
        // Replies come back nested, so the newest top-level copy is enough.
        _comments = [created, ..._comments.where((c) => c.id != created.id)];
        _total += 1;
      } else {
        final parent = parentId;
        _comments = _comments
            .map((c) => c.id == parent
                ? c.withReplies([
                    created,
                    ...c.replies.where((r) => r.id != created.id),
                  ])
                : c)
            .toList(growable: false);
      }
      return true;
    } on DioException catch (e) {
      _error = _errorMessage(e, "Couldn't post your comment. Please try again.");
      return false;
    } catch (_) {
      _error = "Couldn't post your comment. Please try again.";
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  /// DELETE /comments/:id. Returns true on success (removes the comment, and
  /// its replies, from the in-memory list).
  Future<bool> remove(int commentId) async {
    _error = null;
    try {
      await _apiClient.dio.delete('/comments/$commentId');
      final wasTopLevel = _comments.any((c) => c.id == commentId);
      if (wasTopLevel) {
        _comments = _comments.where((c) => c.id != commentId).toList(growable: false);
        _total = math.max(0, _total - 1);
      } else {
        _comments = _comments
            .map((c) => c.replies.any((r) => r.id == commentId)
                ? c.withReplies(c.replies.where((r) => r.id != commentId).toList(growable: false))
                : c)
            .toList(growable: false);
      }
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _errorMessage(e, "Couldn't delete comment");
      notifyListeners();
      return false;
    } catch (_) {
      _error = "Couldn't delete comment";
      notifyListeners();
      return false;
    }
  }

  Comment? _parseComment(Object? body) {
    final data = body is Map<String, dynamic> ? body['data'] : null;
    return data is Map<String, dynamic> ? Comment.fromJson(data) : null;
  }

  String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final err = data['error'];
      if (err is String && err.isNotEmpty) return err;
    }
    return fallback;
  }
}