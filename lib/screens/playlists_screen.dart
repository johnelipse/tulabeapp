import 'package:flutter/material.dart';
import 'package:tulabe/controllers/auth_controller.dart';
import 'package:tulabe/controllers/playlists_controller.dart';
import 'package:tulabe/my_widgets/list_state_widgets.dart';
import 'package:tulabe/my_widgets/playlist_card.dart';
import 'package:tulabe/screens/login_screen.dart';
import 'package:tulabe/screens/playlist_detail_screen.dart';
import '../theme/app_colors.dart';

/// Playlists tab — mirrors the web /playlists page.
/// Tabs (Discover / My Playlists) + search + grid of playlist cards, driven
/// by the Go API (`/playlists?scope=public|mine`).
class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final PlaylistsController _controller = PlaylistsController();
  int _tab = 0; // 0 Discover, 1 My Playlists
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    AuthController.instance.addListener(_onAuthChanged);
    _controller.load(scope: 'public');
  }

  @override
  void dispose() {
    AuthController.instance.removeListener(_onAuthChanged);
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Login/logout can happen underneath this tab (the "SIGN IN" prompt pushes
  // LoginScreen). Re-evaluate the current tab so "My Playlists" flips between
  // the sign-in prompt and the real list without leaving the page.
  void _onAuthChanged() {
    if (!mounted) return;
    if (_tab == 1) {
      _controller.load(scope: 'mine');
    } else {
      setState(() {});
    }
  }

  Future<void> _switchTab(int tab) async {
    if (_tab == tab) return;
    if (!mounted) return;
    setState(() => _tab = tab);
    _searchController.clear();
    _controller.setSearch('');
    await _controller.load(scope: tab == 0 ? 'public' : 'mine');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tabs + "New playlist"
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _TabButton(
                  label: 'DISCOVER',
                  active: _tab == 0,
                  onTap: () => _switchTab(0),
                ),
                const SizedBox(width: 8),
                _TabButton(
                  label: 'MY PLAYLISTS',
                  active: _tab == 1,
                  onTap: () => _switchTab(1),
                ),
                const Spacer(),
                if (_controller.signedIn) _NewPlaylistButton(onTap: _showCreateDialog),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 34,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => _controller.setSearch(v),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: 'Search playlists…',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: Colors.white30, size: 16),
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Body
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Signed out + "My Playlists" -> show the sign-in prompt instead of a 401
    // (mirrors the web's logged-out "mine" state).
    if (_tab == 1 && !_controller.signedIn) {
      return const _SignInEmptyState();
    }
    if (_controller.isLoading) {
      return const _SkeletonGrid();
    }
    final error = _controller.error;
    if (error != null) {
      return ListErrorState(message: error, onRetry: _controller.refresh);
    }
    final playlists = _controller.visible;
    if (playlists.isEmpty) {
      return _EmptyState(
        searched: _controller.search.trim().isNotEmpty,
        isMine: _tab == 1,
      );
    }
    // Cell height = 4:3 collage (width-driven) + title/count lines. Computing it
    // keeps rows snug instead of leaving dead space under each card.
    final cellWidth = (MediaQuery.sizeOf(context).width - 16 * 2 - 14 * 2) / 3;
    final cellHeight = cellWidth * 3 / 4 + 44;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: cellHeight,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final p = playlists[index];
        return PlaylistCard(
          playlist: p,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaylistDetailScreen(playlist: p),
              ),
            );
            // The detail screen mutates the playlist (delete, rename,
            // visibility). Re-fetch so the grid reflects server state instead
            // of showing a stale card that 404s on next tap.
            if (mounted) _controller.refresh();
          },
        );
      },
    );
  }

/// New Playlist dialog (mirrors the web's Create Playlist bar). On success
  /// jumps to "My Playlists" with the new card visible.
  Future<void> _showCreateDialog() async {
    final controller = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String draft = '';
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text(
              'New Playlist',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 200,
              onChanged: (v) => setDialogState(() => draft = v),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: AppColors.primary,
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'Playlist name',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CANCEL', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1)),
              ),
              TextButton(
                onPressed: draft.trim().isEmpty ? null : () => Navigator.pop(dialogContext, draft.trim()),
                child: const Text('CREATE', style: TextStyle(color: AppColors.primary, fontSize: 11, letterSpacing: 1)),
              ),
            ],
          ),
        );
      },
    );
    if (created == null || created.isEmpty) {
      // Don't dispose the controller here: the dialog is still playing its
      // exit transition and the TextField is still attached to it — disposing
      // in the same frame trips the framework's "InheritedElement._dependents"
      // deactivation assert. The controller is GC-collected once the dialog's
      // element tree unmounts.
      return;
    }

    // The dialog is now playing its reverse (exit) transition. Touching the
    // controller/screen from here — including the toast or the tab-switch's
    // notifyListeners — in the same frame can rebuild animate-out widgets and
    // trip Flutter's "InheritedElement._dependents.isEmpty" assert. Wait the
    // transition out before continuing.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final error = await _controller.create(created);
    if (!mounted) return;
    if (error != null) {
      // Deferred past the frame so the toast doesn't register an inherited
      // widget dependency on an element being deactivated.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create playlist: $error')),
        );
      });
      return;
    }
    await _switchTab(1);
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          border: Border.all(color: active ? AppColors.primary : Colors.white12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// "New playlist" pill (only shown when signed in — mirrors the web's
/// user-gated Create Playlist bar).
class _NewPlaylistButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewPlaylistButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: AppColors.primary, size: 14),
            SizedBox(width: 4),
            Text(
              'NEW',
              style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Signed-out "My Playlists" — mirrors the web's logged-out mine state.
class _SignInEmptyState extends StatelessWidget {
  const _SignInEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.video_library_outlined, color: Colors.white24, size: 40),
          const SizedBox(height: 10),
          const Text(
            'Sign in to see your own playlists.',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'SIGN IN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool searched;
  final bool isMine;
  const _EmptyState({required this.searched, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final message = searched
        ? 'No playlists match that search.'
        : isMine
            ? "You haven't made a playlist yet."
            : 'No public playlists yet.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.video_library_outlined, color: Colors.white24, size: 40),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Placeholder grid while the list loads (no shimmer package — mirrors the
/// web's `animate-pulse` skeleton with static translucent tiles).
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 10,
              width: 90,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              height: 8,
              width: 55,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        );
      },
    );
  }
}