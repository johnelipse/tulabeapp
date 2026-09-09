import 'package:flutter/material.dart';
import 'package:tulabe/models/genre.dart';
import 'package:tulabe/models/vj.dart';

import '../theme/app_colors.dart';

/// Full-screen menu drawer — mirrors the web BottomNav drawer.
/// UI only. Navigation is driven by the provided callbacks.
class MenuDrawer extends StatelessWidget {
  final VoidCallback onClose;
  final ValueChanged<int> onNavigate; // 0 Home, 1 Movies, 2 Series, 3 Playlists
  final VoidCallback onLatestDrops;
  final VoidCallback onSearch;
  final VoidCallback onSaved;
  final VoidCallback onClearHistory;
  final VoidCallback onGenre;
  final void Function(Genre genre) onGenreTap;
  final VoidCallback onVJAll;
  final void Function(VJ vj) onVJTap;
  final List<Genre> genres;
  final List<VJ> vjs;

  const MenuDrawer({
    super.key,
    required this.onClose,
    required this.onNavigate,
    required this.onLatestDrops,
    required this.onSearch,
    required this.onSaved,
    required this.onClearHistory,
    required this.onGenre,
    required this.onGenreTap,
    required this.onVJAll,
    required this.onVJTap,
    required this.genres,
    required this.vjs,
  });

  @override
  Widget build(BuildContext context) {
    final genres = this.genres.where((g) => g.isActive).take(12).toList();
    final vjs = this.vjs.where((v) => v.isActive).take(8).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0118),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tulabe Streaming',
                          style: TextStyle(color: Colors.white30, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            // Scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // Navigate
                  const _SectionLabel('Navigate'),
                  const SizedBox(height: 8),
                  _RowItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    onTap: () => onNavigate(0),
                  ),
                  _RowItem(
                    icon: Icons.movie_outlined,
                    label: 'Movies',
                    onTap: () => onNavigate(1),
                  ),
                  _RowItem(
                    icon: Icons.live_tv_outlined,
                    label: 'Series',
                    onTap: () => onNavigate(2),
                  ),
                  _RowItem(
                    icon: Icons.playlist_play_outlined,
                    label: 'Playlists',
                    onTap: () => onNavigate(3),
                  ),
                  _RowItem(
                    icon: Icons.history,
                    label: 'Latest Drops',
                    onTap: onLatestDrops,
                  ),
                  _RowItem(
                    icon: Icons.search,
                    label: 'Search',
                    onTap: onSearch,
                  ),
                  const SizedBox(height: 20),
                  // My Stuff
                  const _SectionLabel('My Stuff'),
                  const SizedBox(height: 8),
                  _RowItem(
                    icon: Icons.bookmark_border,
                    label: 'Saved / Favorites',
                    onTap: onSaved,
                  ),
                  _RowItem(
                    icon: Icons.delete_outline,
                    label: 'Clear Watch History',
                    onTap: onClearHistory,
                    danger: true,
                  ),
                  const SizedBox(height: 20),
                  // Genres
                  if (genres.isNotEmpty) ...[
                    Row(
                      children: [
                        const Expanded(child: _SectionLabel('Genres')),
                        GestureDetector(
                          onTap: onGenre,
                          child: const Text(
                            'All  →',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 3.2,
                      children: genres
                          .map(
                            (g) => _GenreTile(
                              name: g.name,
                              onTap: () => onGenreTap(g),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // VJ Servers
                  if (vjs.isNotEmpty) ...[
                    Row(
                      children: [
                        const Expanded(child: _SectionLabel('VJ Servers')),
                        GestureDetector(
                          onTap: onVJAll,
                          child: const Text(
                            'All  →',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...vjs.map(
                      (vj) => _VJTile(vj: vj, onTap: () => onVJTap(vj)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white24,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _RowItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: danger ? const Color(0xFFF87171) : Colors.white70,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: danger ? const Color(0xFFF87171) : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _GenreTile({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _VJTile extends StatelessWidget {
  final VJ vj;
  final VoidCallback onTap;
  const _VJTile({required this.vj, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: vj.isActive
                    ? const Color(0xFF10B981)
                    : const Color(0xFF52525B),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                vj.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
