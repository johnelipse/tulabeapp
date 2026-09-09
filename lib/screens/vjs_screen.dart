import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tulabe/controllers/vjs_controller.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/my_widgets/list_state_widgets.dart';
import 'package:tulabe/screens/vj_detail_screen.dart';
import '../theme/app_colors.dart';

/// VJs page — mirrors the web `/vjs`: search + grid of circular VJ avatars.
/// Wired to `GET /api/vjs` via [VJsController].
class VJsScreen extends StatefulWidget {
  const VJsScreen({super.key});

  @override
  State<VJsScreen> createState() => _VJsScreenState();
}

class _VJsScreenState extends State<VJsScreen> {
  final VJsController _controller = VJsController();
  final TextEditingController _textController = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _search = value;
      _controller.load(search: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0118),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0118),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white60),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AVAILABLE VJs',
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 3),
                ),
                const SizedBox(height: 6),
                const Text(
                  'THE VJs',
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 2, height: 1.1),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Browse movies narrated by your favourite VJ. Tap any VJ to see their catalogue.',
                  style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 18),
                // Search
                SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _textController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      hintText: 'Search VJs…',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.white30, size: 18),
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildGrid(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final vjs = _controller.vjs;

    if (_controller.loading && vjs.isEmpty) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.58,
        ),
        itemCount: 12,
        itemBuilder: (context, index) => const _VJSkeleton(),
      );
    }

    if (_controller.error != null && vjs.isEmpty) {
      return SizedBox(
        height: 260,
        child: ListErrorState(
          message: 'Failed to load VJs',
          onRetry: () => _controller.load(search: _search),
        ),
      );
    }

    if (vjs.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            _search.trim().isNotEmpty
                ? 'No VJs match "${_search.trim()}".'
                : 'No VJs available yet.',
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.58,
      ),
      itemCount: vjs.length,
      itemBuilder: (context, index) {
        final vj = vjs[index];
        return _VJCard(
          vj: vj,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VJDetailScreen(vjId: '${vj.id}')),
          ),
        );
      },
    );
  }
}

class _VJSkeleton extends StatelessWidget {
  const _VJSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardBg,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 9,
          width: 70,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _VJCard extends StatelessWidget {
  final VJ vj;
  final VoidCallback onTap;
  const _VJCard({required this.vj, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: vj.isActive ? AppColors.primary : Colors.white12, width: 2),
                color: AppColors.surface,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipOval(
                      child: vj.imageUrl.isNotEmpty
                          ? Image.network(
                              vj.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _VJInitial(vj.name),
                            )
                          : _VJInitial(vj.name),
                    ),
                  ),
                  if (vj.isActive)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0A0118), width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            vj.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          if (vj.isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3)),
              child: const Text(
                'LIVE',
                style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            )
          else
            const SizedBox(height: 14),
          if (vj.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              vj.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 9, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _VJInitial extends StatelessWidget {
  final String name;
  const _VJInitial(this.name);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        color: AppColors.surface,
        child: Center(
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}