import 'package:flutter/material.dart';
import 'package:tulabe/controllers/auth_controller.dart';
import 'package:tulabe/controllers/comments_controller.dart';
import 'package:tulabe/models/comment.dart';
import 'package:tulabe/screens/login_screen.dart';
import '../theme/app_colors.dart';

const int _commentMaxLen = 1000;

/// Comments on a movie or series detail page — mirrors the web
/// `comments-section.tsx`: header with count + sort, a YouTube-style composer
/// (signed-in) or a sign-in prompt, one level of replies, "See all", and a
/// keep-it-respectful footer note.
class CommentsSection extends StatefulWidget {
  final String contentType; // 'movie' | 'series'
  final String contentId;

  const CommentsSection({super.key, required this.contentType, required this.contentId});

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final CommentsController _controller = CommentsController();
  final TextEditingController _composer = TextEditingController();
  bool _composerExpanded = false;
  bool _composerBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _controller.load(
      contentType: widget.contentType,
      contentId: widget.contentId,
    );
    if (mounted) setState(() {});
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _submitComment() async {
    final body = _composer.text.trim();
    if (body.length < 2 || _composerBusy) return;
    setState(() => _composerBusy = true);
    final ok = await _controller.add(body: body);
    if (!mounted) return;
    setState(() => _composerBusy = false);
    if (ok) {
      _composer.clear();
      setState(() => _composerExpanded = false);
    } else {
      _toast(_controller.error ?? "Couldn't post your comment. Please try again.");
    }
  }

  void _cancelComposer() {
    _composer.clear();
    setState(() => _composerExpanded = false);
  }

  Future<bool> _reply(int parentId, String body) => _controller.add(body: body, parentId: parentId);

  Future<bool> _delete(int commentId) => _controller.remove(commentId);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final user = _controller.currentUser;
        final signedIn = _controller.signedIn;
        final comments = _controller.comments;
        final total = _controller.total > comments.length ? _controller.total : comments.length;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: "N Comments" + sort
              Row(
                children: [
                  Expanded(
                    child: Text(
                      total > 0 ? '$total Comment${total == 1 ? '' : 's'}' : 'Comments',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (comments.length > 1)
                    _SortButton(
                      sortMode: _controller.sortMode,
                      onSelected: _controller.setSortMode,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Composer or sign-in prompt
              if (signedIn && user != null)
                _Composer(
                  controller: _composer,
                  expanded: _composerExpanded,
                  busy: _composerBusy,
                  initial: user.initial,
                  avatarUrl: user.avatarUrl ?? '',
                  onExpand: () => setState(() => _composerExpanded = true),
                  onSubmit: _submitComment,
                  onCancel: _cancelComposer,
                )
              else
                _SignInPrompt(
                  onLogIn: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),
              const SizedBox(height: 20),
              // Body
              if (_controller.loading) ...[
                const _SkeletonRow(size: 40),
                const SizedBox(height: 18),
                const _SkeletonRow(size: 40),
              ] else if (comments.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'No comments yet — be the first to say something.',
                    style: TextStyle(color: Colors.white30, fontSize: 12.5),
                  ),
                ),
              ] else ...[
                for (final comment in comments) ...[
                  _CommentRow(
                    comment: comment,
                    canDelete: _controller.canDelete(comment),
                    onDelete: _delete,
                    onReply: _reply,
                    onSubmitReplyError: (msg) => _toast(msg),
                  ),
                  const SizedBox(height: 24),
                ],
                if (_controller.canShowMore)
                  GestureDetector(
                    onTap: _controller.loadMore,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'See all comments →',
                        style: TextStyle(
                          color: Color(0xCC04A6ED),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
              ],
              // Footer note
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 12, color: Colors.white24),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Keep it respectful — comments that harass, spam, or contain hateful content will be removed.',
                        style: TextStyle(color: Colors.white24, fontSize: 10.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Underlined field that expands into a full composer (char count, Cancel +
/// Comment buttons) once focused — mirrors the web's CommentComposer.
class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool expanded;
  final bool busy;
  final String initial;
  final String avatarUrl;
  final VoidCallback onExpand;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _Composer({
    required this.controller,
    required this.expanded,
    required this.busy,
    required this.initial,
    required this.avatarUrl,
    required this.onExpand,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final canSubmit = controller.text.trim().length >= 2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(initial: initial, avatarUrl: avatarUrl, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                onTap: onExpand,
                onChanged: (_) => onExpand(),
                maxLines: expanded ? 3 : 1,
                maxLength: _commentMaxLen,
                minLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: 'Add a comment…',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13.5),
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4))),
                ),
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${controller.text.length}/$_commentMaxLen',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: busy ? null : onCancel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: (canSubmit && !busy) ? onSubmit : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: canSubmit ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          busy ? 'POSTING…' : 'COMMENT',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  final VoidCallback onLogIn;
  const _SignInPrompt({required this.onLogIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Sign in to join the conversation.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5),
            ),
          ),
          GestureDetector(
            onTap: onLogIn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'LOG IN',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String sortMode;
  final ValueChanged<String> onSelected;
  const _SortButton({required this.sortMode, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Sort by',
      offset: const Offset(0, 34),
      color: const Color(0xFF15152A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.white12),
      ),
      onSelected: onSelected,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'newest',
          height: 36,
          child: Text(
            'Newest first',
            style: TextStyle(
              color: sortMode == 'newest' ? AppColors.primary : Colors.white70,
              fontSize: 12.5,
            ),
          ),
        ),
        PopupMenuItem(
          value: 'oldest',
          height: 36,
          child: Text(
            'Oldest first',
            style: TextStyle(
              color: sortMode == 'oldest' ? AppColors.primary : Colors.white70,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
      icon: const Icon(Icons.swap_vert, color: Colors.white60, size: 15),
    );
  }
}

class _CommentRow extends StatefulWidget {
  final Comment comment;
  final bool canDelete;
  final Future<bool> Function(int parentId, String body) onReply;
  final Future<bool> Function(int commentId) onDelete;
  final ValueChanged<String> onSubmitReplyError;

  const _CommentRow({
    required this.comment,
    required this.canDelete,
    required this.onReply,
    required this.onDelete,
    required this.onSubmitReplyError,
  });

  @override
  State<_CommentRow> createState() => _CommentRowState();
}

class _CommentRowState extends State<_CommentRow> {
  final TextEditingController _replyController = TextEditingController();
  bool _replying = false;
  bool _repliesOpen = false;
  bool _replyBusy = false;
  bool _deleting = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _toggleReply() async {
    setState(() => _replying = !_replying);
  }

  void _cancelReply() {
    _replyController.clear();
    setState(() => _replying = false);
  }

  Future<void> _submitReply() async {
    final body = _replyController.text.trim();
    if (body.length < 2 || _replyBusy) return;
    setState(() => _replyBusy = true);
    final ok = await widget.onReply(widget.comment.id, body);
    if (!mounted) return;
    setState(() {
      _replyBusy = false;
      if (ok) {
        _replyController.clear();
        _replying = false;
        _repliesOpen = true;
      } else {
        widget.onSubmitReplyError("Couldn't post your reply. Please try again.");
      }
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete this comment?',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This removes the comment and any replies.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontSize: 11, letterSpacing: 1)),
          ),
        ],
      ),
    );
    if (confirmed != true || _deleting) return;
    setState(() => _deleting = true);
    await widget.onDelete(widget.comment.id);
    if (mounted) setState(() => _deleting = false);
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final replyCount = comment.replies.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(initial: comment.user.initial, avatarUrl: comment.user.avatarUrl, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          comment.user.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(comment.createdAt),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.body,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (!widget.comment.isReply) ...[
                        GestureDetector(
                          onTap: _toggleReply,
                          child: const Text(
                            'REPLY',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (widget.canDelete)
                        GestureDetector(
                          onTap: _deleting ? null : _confirmDelete,
                          child: Text(
                            _deleting ? 'DELETING…' : 'DELETE',
                            style: TextStyle(
                              color: _deleting ? Colors.white30 : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        // Reply composer
        if (_replying) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 52),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _replyController,
                      autofocus: true,
                      maxLines: 2,
                      maxLength: _commentMaxLen,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        hintText: 'Reply to ${comment.user.name}…',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13.5),
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4))),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Spacer(),
                        GestureDetector(
                          onTap: _replyBusy ? null : _cancelReply,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Text(
                              'CANCEL',
                              style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: (_replyController.text.trim().length >= 2 && !_replyBusy)
                              ? _submitReply
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _replyController.text.trim().length >= 2
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _replyBusy ? 'POSTING…' : 'REPLY',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        // Replies toggle + thread
        if (replyCount > 0) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _repliesOpen = !_repliesOpen),
            child: Row(
              children: [
                Icon(
                  _repliesOpen ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (_repliesOpen) ...[
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.only(left: 20),
              padding: const EdgeInsets.only(left: 14),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final reply in comment.replies) ...[
                    _CommentRow(
                      comment: reply,
                      canDelete: _replyCanDelete(reply),
                      onReply: widget.onReply,
                      onDelete: widget.onDelete,
                      onSubmitReplyError: widget.onSubmitReplyError,
                    ),
                    if (reply != comment.replies.last) const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  bool _replyCanDelete(Comment reply) {
    final user = AuthController.instance.user;
    if (user == null) return false;
    return user.id == reply.user.id || user.role == 'ADMIN';
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  final String avatarUrl;
  final double size;
  const _Avatar({required this.initial, required this.avatarUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl.isNotEmpty;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (!hasImage) return fallback;
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  final double size;
  const _SkeletonRow({required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: size == 40 ? 90 : 70,
                height: 9,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 9,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  final sec = diff.inSeconds < 0 ? 0 : diff.inSeconds;
  if (sec < 60) return 'just now';
  final min = sec ~/ 60;
  if (min < 60) return '${min}m ago';
  final hr = min ~/ 60;
  if (hr < 24) return '${hr}h ago';
  final day = hr ~/ 24;
  if (day < 30) return '${day}d ago';
  final month = day ~/ 30;
  if (month < 12) return '${month}mo ago';
  return '${month ~/ 12}y ago';
}