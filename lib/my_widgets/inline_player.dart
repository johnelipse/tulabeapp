import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tulabe/controllers/playback_controller.dart';
import 'package:tulabe/controllers/watch_progress_store.dart';
import 'package:tulabe/models/movies.dart';

import '../theme/app_colors.dart';

/// Inline, in-page HLS player that mirrors the web player embedded in the
/// top of the movie/series detail screens. It shows a 16:9 poster with a play
/// button until playback is requested; once the stream is ready it swaps in a
/// [BetterPlayer] in the exact same spot — no separate screen, no navigation.
///
/// Stream source: the direct 1080p variant playlist (`qualities[].playlist_url`,
/// on the CDN) when available — this is what the web player's ABR resolves to
/// first — otherwise the API `master_url` HLS playlist, otherwise the API
/// `direct_url` (a progressive file, e.g. `.mkv`) when the title has no HLS
/// yet. This keeps the app on the same media path instead of routing through
/// the extra `/api/stream` proxy hop.
///
/// Any error reported by ExoPlayer is surfaced as an on-screen banner with a
/// retry. A 12-second watchdog converts a silent "buffering forever" state
/// into an actionable error instead of a spinner that never ends.
class InlinePlayer extends StatefulWidget {
  final String movieId;
  final String? title;
  final String? thumbnailUrl;

  /// When set (seconds > 0), the player auto-plays and seeks here once the
  /// stream initializes — used by the "Continue Watching" resume flow and to
  /// pass the resume position into a newly selected series episode.
  final double resumeFrom;

  /// Set when [movieId] is a series episode's `stream_movie_id` — lets the
  /// progress store link the entry back to its series page for resume.
  final String? seriesId;

  const InlinePlayer({
    super.key,
    required this.movieId,
    this.title,
    this.thumbnailUrl,
    this.resumeFrom = 0,
    this.seriesId,
  });

  @override
  State<InlinePlayer> createState() => InlinePlayerState();
}

class InlinePlayerState extends State<InlinePlayer> {
  static const String _fitPrefKey = 'inline_player_fit';

  final PlaybackController _playback = PlaybackController();
  BetterPlayerController? _player;
  String? _activeUrl;
  String? _streamError;
  bool _requested = false;
  bool _started = false;
  Timer? _watchdog;

  /// Resume position to seek once the stream initializes (seconds).
  double? _pendingSeek;

  /// Last known playback position/duration (updated on progress events).
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  int _lastProgressSaveMs = 0;

  /// How the video fills the player box, YouTube-style.
  /// [BoxFit.contain] = original size, letterboxed (black bars around);
  /// [BoxFit.cover] = scale up until it fills the box, cropping the overflow.
  final ValueNotifier<BoxFit> _fitValue = ValueNotifier(BoxFit.contain);

  /// Tracked from better_player's controls-visible events so the fit buttons
  /// fade in/out exactly like the native player controls.
  final ValueNotifier<bool> _controlsVisible = ValueNotifier(true);

  BoxFit get _fit => _fitValue.value;

  /// Long side / short side of the physical display. Used as the fullscreen
  /// aspect ratio so the video box matches the phone screen exactly — with
  /// [BoxFit.cover] the video then truly covers the whole screen.
  double get _screenRatio {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final size = view.physicalSize;
      if (size.isEmpty) return 16 / 9;
      return size.longestSide / size.shortestSide;
    } catch (_) {
      return 16 / 9;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.resumeFrom > 0) {
      _requested = true;
      _pendingSeek = widget.resumeFrom;
    }
    _loadPlayback();
    _loadFitPreference();
  }

  Future<void> _loadFitPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_fitPrefKey);
    if (!mounted || stored == null) return;
    final fit = stored == 'cover' ? BoxFit.cover : BoxFit.contain;
    _fitValue.value = fit;
    _player?.setOverriddenFit(fit);
  }

  void _setFit(BoxFit fit) {
    if (_fitValue.value == fit) return;
    _fitValue.value = fit;
    _player?.setOverriddenFit(fit);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(
        _fitPrefKey,
        fit == BoxFit.cover ? 'cover' : 'contain',
      ),
    );
  }

  @override
  void didUpdateWidget(covariant InlinePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieId != widget.movieId) {
      _saveProgress();
      _disposePlayer();
      _requested = false;
      _started = false;
      _pendingSeek = null;
      _streamError = null;
      _stopWatchdog();
      _loadPlayback();
    }
  }

  @override
  void dispose() {
    _stopWatchdog();
    _saveProgress();
    _disposePlayer();
    _playback.dispose();
    _fitValue.dispose();
    _controlsVisible.dispose();
    super.dispose();
  }

  void _disposePlayer() {
    _player?.dispose();
    _player = null;
    _activeUrl = null;
  }

  void _stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  void _startWatchdog() {
    _stopWatchdog();
    _watchdog = Timer(const Duration(seconds: 12), () {
      if (!mounted || _started || _streamError != null) return;
      setState(
        () => _streamError = 'Video is buffering but never starts. Check your connection and retry.',
      );
      debugPrint('[InlinePlayer] start watchdog fired (not started, no error)');
    });
  }

  /// Resolves the URL + stream format to feed the player. Prefers the 1080p
  /// variant playlist, then the HLS master playlist, then a direct file.
  /// Returns null when the payload has no playable source at all.
  (String, VideoFormat)? _resolveStream(PlaybackData data) {
    for (final q in data.qualities) {
      if (q.quality == '1080p' && q.playlistUrl.isNotEmpty) {
        return (q.playlistUrl, VideoFormat.hls);
      }
    }
    if (data.masterUrl.isNotEmpty) return (data.masterUrl, VideoFormat.hls);
    if (data.qualities.isNotEmpty &&
        data.qualities.first.playlistUrl.isNotEmpty) {
      return (data.qualities.first.playlistUrl, VideoFormat.hls);
    }
    if (data.directUrl.isNotEmpty) return (data.directUrl, VideoFormat.other);
    return null;
  }

  Future<void> _loadPlayback() async {
    final id = widget.movieId;
    if (id.isEmpty) return;
    await _playback.load(id);
    if (!mounted) return;
    debugPrint(
      '[InlinePlayer] playback loaded: '
      '${_playback.data?.title} status=${_playback.status.name} '
      'error=${_playback.error}',
    );
    setState(() {});
    if (_requested) _attachIfReady();
  }

  /// Public entry point used by the detail screens' play buttons — starts
  /// playback in place. Safe to call multiple times.
  void start() {
    if (widget.movieId.isEmpty) return;
    _requested = true;
    if (mounted) setState(() {});
    _attachIfReady();
  }

  void _attachIfReady() {
    if (!_requested) return;
    final data = _playback.data;
    if (data == null || data.status != MovieStatus.ready) return;
    final resolved = _resolveStream(data);
    if (resolved == null) {
      if (mounted) {
        setState(() {
          _streamError = 'No playable stream for this title yet.';
        });
      }
      return;
    }
    final url = resolved.$1;
    final videoFormat = resolved.$2;
    if (_activeUrl == url && _player != null) return;

    debugPrint('[InlinePlayer] attaching to stream: $url');

    final controller = BetterPlayerController(
      PlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: _fit,
        // Match the phone screen exactly in fullscreen so "Fill" covers every
        // pixel (no black borders) while "Fit" keeps the letterboxed look.
        fullScreenAspectRatio: _screenRatio,
        // We build the fullscreen page ourselves so the Fit/Fill buttons render
        // ABOVE the controls' gesture layer and stay tappable in fullscreen.
        routePageBuilder: (context, animation, secondaryAnimation, provider) {
          return AnimatedBuilder(
            animation: _fitValue,
            builder: (context, _) => Scaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: Colors.black,
              body: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: Stack(
                  fit: StackFit.expand,
                  children: [provider, _fitControls()],
                ),
              ),
            ),
          );
        },
        autoPlay: true,
        handleLifecycle: true,
        // Debug everything, including forwarding native ExoPlayer logs to the
        // Flutter console so logcat pinpoints exactly where playback stalls.
        playerLogConfiguration: const PlayerLoggerConfiguration(
          logLevel: PlayerLogLevel.debug,
          printCallerInfo: false,
        ),
        // The overflow menu opens a Material bottom sheet without a navigator
        // context from the detail screen — disable it to avoid the crash and
        // keep the controls minimal (single-quality streams anyway).
        controlsConfiguration: const PlayerControlsConfiguration(
          enableOverflowMenu: false,
          enablePip: false,
          enableAudioTracks: false,
          enableQualities: false,
          enableRetry: true,
        ),
      ),
      betterPlayerDataSource: PlayerDataSource(
        DataSourceType.network,
        url,
        liveStream: false,
        videoFormat: videoFormat,
      ),
    );

    controller.addEventsListener(_onPlayerEvent);
    _disposePlayer();
    _activeUrl = url;
    _player = controller;
    _streamError = null;
    _started = false;
    _startWatchdog();
    if (mounted) setState(() {});
  }

  void _onPlayerEvent(PlayerEvent event) {
    debugPrint('[InlinePlayer] event: ${event.betterPlayerEventType}');
    switch (event.betterPlayerEventType) {
      case PlayerEventType.exception:
        final message = (event.parameters?['exception'] as String?)?.trim();
        if (mounted && message != null && message.isNotEmpty) {
          setState(() => _streamError = message);
        }
        if (mounted && !_started) {
          _started = true;
          _stopWatchdog();
        }
        break;
      case PlayerEventType.initialized:
        if (mounted && !_started) {
          _started = true;
          _stopWatchdog();
        }
        _applyPendingSeek();
        break;
      case PlayerEventType.play:
        if (mounted && !_started) {
          _started = true;
          _stopWatchdog();
        }
        break;
      case PlayerEventType.finished:
        if (mounted) {
          _started = true;
          _stopWatchdog();
        }
        _saveProgress();
        break;
      case PlayerEventType.pause:
        _saveProgress();
        break;
      case PlayerEventType.progress:
        final pos = event.parameters?['progress'];
        final dur = event.parameters?['duration'];
        if (pos is Duration) _lastPosition = pos;
        if (dur is Duration) _lastDuration = dur;
        _maybeSaveProgress();
        break;
      case PlayerEventType.setupDataSource:
      case PlayerEventType.bufferingStart:
      case PlayerEventType.bufferingUpdate:
      case PlayerEventType.bufferingEnd:
      case PlayerEventType.seekTo:
        break;
      case PlayerEventType.controlsVisible:
      case PlayerEventType.openFullscreen:
      case PlayerEventType.hideFullscreen:
        _controlsVisible.value = true;
        break;
      case PlayerEventType.controlsHiddenStart:
      case PlayerEventType.controlsHiddenEnd:
        _controlsVisible.value = false;
        break;
      default:
        break;
    }
  }

  /// Seeks to the stored resume position once (after the stream is ready).
  void _applyPendingSeek() {
    final target = _pendingSeek;
    if (target == null || target <= 0) return;
    _pendingSeek = null;
    final player = _player;
    if (player == null) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _player != player) return;
      try {
        player.seekTo(Duration(milliseconds: (target * 1000).round()));
      } catch (_) {
        // Engine not fully ready yet — the seek is best-effort.
      }
    });
  }

  /// Saves the last known position to the progress store, mirroring the web
  /// player's `saveProgress`. Guards against pre-init/buffered-skip positions.
  void _saveProgress() {
    final position = _lastPosition.inMilliseconds / 1000.0;
    final duration = _lastDuration.inMilliseconds / 1000.0;
    if (position <= 0 || duration <= 0) return;
    WatchProgressStore.instance.saveProgress(
      movieId: widget.movieId,
      title: widget.title ?? '',
      thumbnailUrl: widget.thumbnailUrl ?? '',
      currentTime: position,
      duration: duration,
      seriesId: widget.seriesId,
    );
  }

  /// Throttled progress persistence (~every 5s while playing).
  void _maybeSaveProgress() {
    if (!_started) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProgressSaveMs < 5000) return;
    _lastProgressSaveMs = now;
    _saveProgress();
  }

  void _retry() {
    _disposePlayer();
    _stopWatchdog();
    if (mounted) {
      setState(() {
        _streamError = null;
        _started = false;
      });
    }
    _loadPlayback();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_player != null)
              // Rebuild the player when the fit changes so the video surface
              // re-reads the override without restarting the stream.
              AnimatedBuilder(
                animation: _fitValue,
                builder: (context, _) => BetterPlayer(controller: _player!),
              )
            else
              _buildIdleState(),
            if (_player != null) _fitControls(),
            if (_player != null && _streamError != null)
              _buildStreamErrorBanner(),
          ],
        ),
      ),
    );
  }

  /// Fit/Fill toggle buttons, layered ABOVE the player's controls so they are
  /// always tappable. Fades in/out with the native controls and highlights the
  /// active mode. Used both inline and inside our custom fullscreen page.
  Widget _fitControls() {
    return ValueListenableBuilder<bool>(
      valueListenable: _controlsVisible,
      builder: (context, show, _) => IgnorePointer(
        ignoring: !show,
        child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: ValueListenableBuilder<BoxFit>(
            valueListenable: _fitValue,
            builder: (context, currentFit, _) => Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 56, right: 8),
                child: Column(
                  children: [
                    _FitToggle(
                      label: 'Fit',
                      icon: Icons.fit_screen,
                      active: currentFit == BoxFit.contain,
                      onTap: () => _setFit(BoxFit.contain),
                    ),
                    const SizedBox(height: 6),
                    _FitToggle(
                      label: 'Fill',
                      icon: Icons.fullscreen,
                      active: currentFit == BoxFit.cover,
                      onTap: () => _setFit(BoxFit.cover),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdleState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Poster
        if ((widget.thumbnailUrl ?? '').isNotEmpty)
          Image.network(
            widget.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: AppColors.surface),
          )
        else
          Container(color: AppColors.surface),
        // Mask so the play button and text read on any poster
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent, Colors.transparent],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black45, Colors.transparent, Colors.black45],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        if (!_requested)
          Center(
            child: GestureDetector(
              onTap: start,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          )
        else
          _buildPreparingOverlay(),
      ],
    );
  }

  Widget _buildPreparingOverlay() {
    if (_playback.loading || _playback.data == null) {
      return const _CenterColumn(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'PREPARING VIDEO',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      );
    }

    final error = _streamError ?? _playback.error;
    if (error != null) {
      return _CenterColumn(
        children: [
          const Icon(Icons.cloud_off, color: Colors.white38, size: 34),
          const SizedBox(height: 8),
          const Text(
            'FAILED TO LOAD STREAM',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _RetryButton(onTap: _retry),
        ],
      );
    }

    switch (_playback.status) {
      case MovieStatus.queued:
      case MovieStatus.pending:
      case MovieStatus.processing:
        return const _CenterColumn(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'PREPARING VIDEO',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'This video is being processed for streaming.\nCheck back in a few minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        );
      case MovieStatus.failed:
        return const _CenterColumn(
          children: [
            Icon(Icons.error_outline, color: Colors.white30, size: 34),
            SizedBox(height: 8),
            Text(
              'VIDEO NOT AVAILABLE',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 12),
          ],
        );
      case MovieStatus.ready:
    }
    return const _CenterColumn(
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'STARTING STREAM…',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildStreamErrorBanner() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _streamError!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
            const SizedBox(width: 8),
            _RetryButton(onTap: _retry, compact: true),
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _RetryButton({required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: compact ? 6 : 9,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(compact ? 5 : 6),
        ),
        child: Text(
          'RETRY',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _CenterColumn extends StatelessWidget {
  final List<Widget> children;
  const _CenterColumn({required this.children});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _FitToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _FitToggle({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: label,
        button: true,
        selected: active,
        child: Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.85)
                : Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? Colors.white : Colors.white24,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
