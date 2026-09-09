import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tulabe/controllers/auth_controller.dart';
import 'package:tulabe/models/playlist.dart';
import 'package:tulabe/screens/login_screen.dart';
import 'package:tulabe/services/api_client.dart';
import '../theme/app_colors.dart';

/// Entry point used by both detail screens. Signed-out users get a sign-in
/// prompt (which pushes [LoginScreen]); signed-in users get the
/// Save-to-Playlist sheet.
Future<void> showSaveToPlaylist(
  BuildContext context, {
  required String contentType, // 'movie' | 'series'
  required String contentId,
}) async {
  if (!AuthController.instance.isAuthenticated) {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _SignInSheet(
        onLogIn: () {
          Navigator.pop(sheetContext);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        },
      ),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SaveToPlaylistSheet(contentType: contentType, contentId: contentId),
  );
}

/// Mirrors the web's `components/shared/save-to-playlist-modal.tsx` — lists the
/// signed-in user's playlists so they can quickly save the current movie or
/// series to one (or create a new playlist and add it in one step).
class SaveToPlaylistSheet extends StatefulWidget {
  final String contentType;
  final String contentId;

  const SaveToPlaylistSheet({super.key, required this.contentType, required this.contentId});

  @override
  State<SaveToPlaylistSheet> createState() => _SaveToPlaylistSheetState();
}

class _SaveToPlaylistSheetState extends State<SaveToPlaylistSheet> {
  final ApiClient _api = ApiClient();

  List<Playlist> _playlists = const [];
  Set<String> _added = <String>{};
  String _savingId = '';
  bool _loading = true;
  String? _error;
  bool _creating = false;
  bool _createMode = false;
  final TextEditingController _createController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  // Deferred to the next frame so an open/close transition of the sheet can
  // never trigger a fresh ScaffoldMessenger dependency while the inherited
  // element is being deactivated (framework.dart debugDeactivated assert).
  void _toast(String message) {
    if (!mounted) return;
    final context = this.context;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 2),
        ));
    });
  }

  // Same idea as _toast: the very first load fires while the modal is still
  // animating in, so defer the request (and its setState) until after the frame.
  Future<void> _load() async {
    await _deferred();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.dio.get('/playlists', queryParameters: {'scope': 'mine'});
      if (!mounted) return;
      final body = response.data;
      var playlists = const <Playlist>[];
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          playlists = Playlist.listFromJson(data['playlists']);
        }
      }
      setState(() => _playlists = playlists);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't load your playlists.");
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deferred() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      return Future.value();
    }
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    return completer.future;
  }

  Future<void> _addTo(Playlist playlist) async {
    if (_savingId.isNotEmpty) return;
    setState(() => _savingId = playlist.id);
    try {
      await _api.dio.post('/playlists/${playlist.id}/items', data: {
        'content_type': widget.contentType,
        'content_id': widget.contentId,
      });
      if (!mounted) return;
      setState(() => _added = {..._added, playlist.id});
    } catch (_) {
      if (!mounted) return;
      _toast("Couldn't save to \"${playlist.title}\". Please try again.");
    }
    if (mounted) setState(() => _savingId = '');
  }

  Future<void> _createAndAdd() async {
    final title = _createController.text.trim();
    if (title.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final createResp = await _api.dio.post('/playlists', data: {'title': title});
      if (!mounted) return;
      var createdId = '';
      final body = createResp.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          final raw = data['playlist'];
          if (raw is Map<String, dynamic>) createdId = raw['id']?.toString() ?? '';
        }
      }
      if (createdId.isEmpty) throw Exception('no playlist id');
      await _api.dio.post('/playlists/$createdId/items', data: {
        'content_type': widget.contentType,
        'content_id': widget.contentId,
      });
      if (!mounted) return;
      _createController.clear();
      setState(() {
        _added = {..._added, createdId};
        _createMode = false;
      });
      _toast('Playlist "$title" created and this item was saved to it.');
      await _load();
    } catch (_) {
      if (!mounted) return;
      _toast("Couldn't create the playlist. Please try again.");
    }
    if (mounted) setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'SAVE TO PLAYLIST',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pick a playlist to save this to.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
                )
              else if (_error != null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _load,
                        child: const Text('RETRY',
                            style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _playlists.length + 1, // +1 = "new playlist" row
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == _playlists.length) return _buildCreateRow();
                      final p = _playlists[index];
                      return _PlaylistRow(
                        playlist: p,
                        added: _added.contains(p.id),
                        saving: _savingId == p.id,
                        onTap: () => _addTo(p),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateRow() {
    if (_createMode) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _createController,
              autofocus: true,
              maxLength: 200,
              onSubmitted: (_) => _createAndAdd(),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              cursorColor: AppColors.primary,
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'New playlist name…',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _creating ? null : _createAndAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _createController.text.trim().isEmpty ? AppColors.primary.withValues(alpha: 0.3) : AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _creating ? '…' : 'CREATE',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _createMode = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.add, color: AppColors.primary, size: 16),
            SizedBox(width: 8),
            Text(
              'New playlist',
              style: TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  final Playlist playlist;
  final bool added;
  final bool saving;
  final VoidCallback onTap;

  const _PlaylistRow({
    required this.playlist,
    required this.added,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: added ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: added ? AppColors.primary.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: added ? AppColors.primary.withValues(alpha: 0.4) : Colors.white10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                playlist.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            if (playlist.itemCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '${playlist.itemCount}',
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                ),
              ),
            if (saving)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              )
            else
              Icon(
                added ? Icons.check_circle : Icons.playlist_add,
                color: added ? AppColors.primary : Colors.white.withValues(alpha: 0.4),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _SignInSheet extends StatelessWidget {
  final VoidCallback onLogIn;
  const _SignInSheet({required this.onLogIn});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.playlist_add, color: AppColors.primary, size: 34),
            const SizedBox(height: 10),
            const Text(
              'Sign in to save to playlists',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your playlists sync across devices.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onLogIn,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'LOG IN',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}