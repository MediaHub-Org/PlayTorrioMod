import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/iptv/iptv_models.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/playback_coordinator.dart';
import '../../services/player/player_settings.dart';

class IptvPlayerPage extends StatefulWidget {
  final HardcodedChannel channel;
  final List<ChannelHit> hits;
  final int initialHitIndex;
  final bool? isLive;
  final String? categoryTitle;

  const IptvPlayerPage({
    super.key,
    required this.channel,
    required this.hits,
    this.initialHitIndex = 0,
    this.isLive,
    this.categoryTitle,
  });

  @override
  State<IptvPlayerPage> createState() => _IptvPlayerPageState();
}

class _IptvPlayerPageState extends State<IptvPlayerPage>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  late int _activeHitIndex;
  bool _isLoading = true;
  String _statusMessage = 'Connecting to stream…';
  bool _showControls = true;
  bool _showSourcesDrawer = false;
  Timer? _hideControlsTimer;
  Timer? _watchdogTimer;
  late final ScrollController _sourcesScrollController;

  BoxFit _videoFit = BoxFit.contain;
  double _volume = 1.0;
  bool _isMuted = false;
  bool _showVolumeHud = false;
  Timer? _volumeHudTimer;

  // Stream watchdog metrics
  Duration _lastPosition = Duration.zero;
  DateTime _lastPositionChange = DateTime.now();
  int _retryCount = 0;

  bool get _isLiveStream {
    if (widget.isLive != null) return widget.isLive!;
    final currentHit = widget.hits.isNotEmpty && _activeHitIndex < widget.hits.length
        ? widget.hits[_activeHitIndex]
        : null;
    final kind = currentHit?.stream.kind.toLowerCase();
    if (kind == 'movie' || kind == 'series' || kind == 'vod') return false;
    final cat = widget.channel.category.toLowerCase();
    if (cat.contains('movie') || cat.contains('series') || cat.contains('vod') || cat.contains('show')) {
      return false;
    }
    return true;
  }

  bool get _isCategoryList {
    if (widget.hits.length <= 1) return false;
    if (widget.categoryTitle != null && widget.categoryTitle!.isNotEmpty) return true;
    return widget.hits.first.stream.streamId != widget.hits.last.stream.streamId;
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _activeHitIndex = widget.initialHitIndex.clamp(0, widget.hits.length - 1);
    _sourcesScrollController = ScrollController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initPlayer();
    if (_isLiveStream) {
      _startWatchdog();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _hideControlsTimer?.cancel();
    _watchdogTimer?.cancel();
    _volumeHudTimer?.cancel();
    _sourcesScrollController.dispose();
    PlaybackCoordinator.release('iptv:${widget.channel.id}');
    _controller?.removeListener(_onPlaybackUpdate);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _onPlaybackUpdate() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return;
    PlaybackCoordinator.setProgress(value.position, value.duration);
    PlaybackCoordinator.setPlaying(value.isPlaying);
  }

  Future<void> _initPlayer() async {
    if (widget.hits.isEmpty) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'No stream sources available for this channel.';
      });
      return;
    }

    final currentHit = widget.hits[_activeHitIndex];
    final streamUrl = currentHit.streamUrl;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Buffering ${currentHit.stream.name.isNotEmpty ? currentHit.stream.name : currentHit.portal.name}…';
    });

    try {
      _controller?.removeListener(_onPlaybackUpdate);
      await _controller?.dispose();
      _controller = null;

      final cleanUri = Uri.parse(streamUrl);
      _controller = VideoPlayerController.networkUrl(
        cleanUri,
        httpHeaders: const {
          'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      );

      // Ensure only one source plays app-wide: stop any other active source.
      // Keyed by channel (not by hit/source), so switching sources or
      // reconnecting the same channel doesn't re-register with the
      // coordinator.
      PlaybackCoordinator.activate(
        'iptv:${widget.channel.id}',
        () => _controller?.pause(),
        kind: 'video',
        title: widget.channel.name,
        subtitle: widget.categoryTitle ?? widget.channel.category,
        coverUrl: widget.channel.iconUrl ?? widget.channel.backdropUrl,
        onTogglePlayPause: () {
          if (_controller == null) return;
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          } else {
            _controller!.play();
          }
        },
        onSeek: (position) => _controller?.seekTo(position),
      );

      PlayerSettings.applyToController(_controller!);
      await _controller!.initialize();
      PlayerSettings.applyToController(_controller!);
      await _controller!.setVolume(_isMuted ? 0.0 : _volume);
      await _controller!.play();
      _controller!.addListener(_onPlaybackUpdate);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _retryCount = 0;
        _lastPosition = Duration.zero;
        _lastPositionChange = DateTime.now();
      });

      _startHideControlsTimer();
    } catch (e) {
      debugPrint('[IPTV Player Error] $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Feed failed. Trying alternative source…';
      });

      // Auto-failover to next hit if available
      if (widget.hits.length > 1 && _retryCount < 3) {
        _retryCount++;
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          final nextIdx = (_activeHitIndex + 1) % widget.hits.length;
          _switchSource(nextIdx);
        });
      }
    }
  }

  void _switchSource(int index) {
    if (index < 0 || index >= widget.hits.length) return;
    setState(() {
      _activeHitIndex = index;
      _showSourcesDrawer = false;
    });
    _initPlayer();
  }

  void _openSourcesDrawer() {
    setState(() => _showSourcesDrawer = true);
    _hideControlsTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sourcesScrollController.hasClients) {
        final targetOffset = (_activeHitIndex * 62.0) - 120.0;
        final maxOffset = _sourcesScrollController.position.maxScrollExtent;
        final safeOffset = targetOffset.clamp(0.0, maxOffset);
        _sourcesScrollController.animateTo(
          safeOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _controller == null || !_controller!.value.isInitialized) {
        return;
      }

      final isPlaying = _controller!.value.isPlaying;
      final currentPos = _controller!.value.position;

      if (isPlaying && currentPos != _lastPosition) {
        _lastPosition = currentPos;
        _lastPositionChange = DateTime.now();
      }

      // If live and position frozen for > 10 seconds, trigger reconnect
      if (_isLiveStream &&
          isPlaying &&
          DateTime.now().difference(_lastPositionChange).inSeconds > 10 &&
          !_isLoading) {
        debugPrint('[IPTV Watchdog] Stream frozen > 10s — reconnecting…');
        _initPlayer();
      }
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && !_showSourcesDrawer) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (!_showControls) _showSourcesDrawer = false;
    });
    if (_showControls) _startHideControlsTimer();
  }

  void _cycleVideoFit() {
    setState(() {
      if (_videoFit == BoxFit.contain) {
        _videoFit = BoxFit.cover;
      } else if (_videoFit == BoxFit.cover) {
        _videoFit = BoxFit.fill;
      } else {
        _videoFit = BoxFit.contain;
      }
    });
  }

  void _seekRelative(int seconds) {
    if (_controller == null || !_controller!.value.isInitialized || _isLiveStream) return;
    final cur = _controller!.value.position;
    final max = _controller!.value.duration;
    final target = cur + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > max ? max : target);
    _controller!.seekTo(clamped);
    _startHideControlsTimer();
    setState(() {});
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
    _startHideControlsTimer();
  }

  void _adjustVolume(double delta) {
    setState(() {
      if (_isMuted && delta > 0) {
        _isMuted = false;
      }
      _volume = (_volume + delta).clamp(0.0, 1.0);
      if (_volume == 0.0) {
        _isMuted = true;
      } else if (_isMuted) {
        _isMuted = false;
      }
      _controller?.setVolume(_isMuted ? 0.0 : _volume);
      _showVolumeHud = true;
    });
    _volumeHudTimer?.cancel();
    _volumeHudTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showVolumeHud = false);
    });
    _startHideControlsTimer();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (!_isMuted && _volume == 0) {
        _volume = 0.5;
      }
      _controller?.setVolume(_isMuted ? 0.0 : _volume);
      _showVolumeHud = true;
    });
    _volumeHudTimer?.cancel();
    _volumeHudTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showVolumeHud = false);
    });
    _startHideControlsTimer();
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final currentHit = widget.hits.isNotEmpty ? widget.hits[_activeHitIndex] : null;
    final isLive = _isLiveStream;
    final isCategoryList = _isCategoryList;
    final currentTitle = currentHit != null && currentHit.stream.name.isNotEmpty
        ? currentHit.stream.name
        : ch.name;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _togglePlayPause();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && !isLive) {
            _seekRelative(-10);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && !isLive) {
            _seekRelative(10);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _adjustVolume(0.05);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _adjustVolume(-0.05);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.pageDown || event.logicalKey == LogicalKeyboardKey.keyN) {
            if (_activeHitIndex + 1 < widget.hits.length) {
              _switchSource(_activeHitIndex + 1);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.pageUp || event.logicalKey == LogicalKeyboardKey.keyP) {
            if (_activeHitIndex - 1 >= 0) {
              _switchSource(_activeHitIndex - 1);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
            _toggleMute();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
            _cycleVideoFit();
            _startHideControlsTimer();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              if (pointerSignal.scrollDelta.dy < 0) {
                _adjustVolume(0.05); // Scroll up -> Volume up
              } else if (pointerSignal.scrollDelta.dy > 0) {
                _adjustVolume(-0.05); // Scroll down -> Volume down
              }
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video Surface
                if (_controller != null && _controller!.value.isInitialized)
                  Center(
                    child: FittedBox(
                      fit: _videoFit,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                else if (!_isLoading)
                  Center(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),

                // Loading / Buffering Banner
                if (_isLoading)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF7C5CFF).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF7C5CFF),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Volume HUD Overlay (when changing volume)
                if (_showVolumeHud)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xE60D101A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF7C5CFF).withValues(alpha: 0.6), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C5CFF).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isMuted || _volume == 0
                                  ? Icons.volume_off_rounded
                                  : (_volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                              color: _isMuted ? Colors.redAccent : const Color(0xFF00D2EF),
                              size: 28,
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 130,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _isMuted ? 0.0 : _volume,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _isMuted ? Colors.redAccent : const Color(0xFF7C5CFF),
                                  ),
                                  minHeight: 7,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isMuted ? 'MUTED' : '${(_volume * 100).toInt()}%',
                              style: TextStyle(
                                color: _isMuted ? Colors.redAccent : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Controls Overlay
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showControls ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Top Bar
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xCC000000), Colors.transparent],
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isLive ? const Color(0xFFFF3B30) : const Color(0xFF7C5CFF),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isLive
                                                  ? 'LIVE'
                                                  : (ch.category.isNotEmpty ? ch.category.toUpperCase() : 'VOD'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              currentTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (currentHit != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          isCategoryList
                                              ? 'Channel ${_activeHitIndex + 1}/${widget.hits.length} · ${currentHit.portal.name}'
                                              : 'Source ${_activeHitIndex + 1}/${widget.hits.length} · ${currentHit.portal.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Category Channels / Sources Drawer Toggle
                                if (widget.hits.length > 1)
                                  IconButton(
                                    icon: Icon(
                                      isCategoryList ? Icons.format_list_bulleted_rounded : Icons.video_library_rounded,
                                      color: Colors.white,
                                    ),
                                    tooltip: isCategoryList
                                        ? (widget.categoryTitle ?? 'Category Channels')
                                        : 'Alternative Feeds',
                                    onPressed: _openSourcesDrawer,
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Bottom Bar
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0xCC000000), Colors.transparent],
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── SEEKBAR (ONLY FOR MOVIES & SHOWS / VOD) ──
                                if (!isLive && _controller != null && _controller!.value.isInitialized) ...[
                                  _IptvCustomProgressBar(
                                    controller: _controller!,
                                    onSeekStart: () => _hideControlsTimer?.cancel(),
                                    onSeekEnd: () => _startHideControlsTimer(),
                                  ),
                                  const SizedBox(height: 6),
                                ],

                                // Controls Buttons Row
                                Row(
                                  children: [
                                    // Play / Pause
                                    IconButton(
                                      icon: Icon(
                                        _controller != null && _controller!.value.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                      onPressed: _togglePlayPause,
                                    ),

                                    if (!isLive && _controller != null && _controller!.value.isInitialized) ...[
                                      const SizedBox(width: 4),
                                      // Replay -10s
                                      IconButton(
                                        icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 24),
                                        tooltip: 'Seek -10s',
                                        onPressed: () => _seekRelative(-10),
                                      ),
                                      // Forward +10s
                                      IconButton(
                                        icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 24),
                                        tooltip: 'Seek +10s',
                                        onPressed: () => _seekRelative(10),
                                      ),
                                      const SizedBox(width: 8),
                                      // Position / Duration Readout
                                      ValueListenableBuilder<VideoPlayerValue>(
                                        valueListenable: _controller!,
                                        builder: (context, value, _) {
                                          return Text(
                                            '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'monospace',
                                            ),
                                          );
                                        },
                                      ),
                                    ],

                                    const SizedBox(width: 8),

                                    // ── INTERACTIVE VOLUME SLIDER & MUTE TOGGLE ──
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            _isMuted || _volume == 0
                                                ? Icons.volume_off_rounded
                                                : (_volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                                            color: _isMuted ? Colors.redAccent : Colors.white,
                                            size: 22,
                                          ),
                                          tooltip: _isMuted ? 'Unmute (M)' : 'Mute (M)',
                                          onPressed: _toggleMute,
                                        ),
                                        SizedBox(
                                          width: 86,
                                          child: SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              trackHeight: 3.5,
                                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                              activeTrackColor: const Color(0xFF7C5CFF),
                                              inactiveTrackColor: Colors.white24,
                                              thumbColor: Colors.white,
                                            ),
                                            child: Slider(
                                              value: _isMuted ? 0.0 : _volume,
                                              min: 0.0,
                                              max: 1.0,
                                              onChanged: (val) {
                                                setState(() {
                                                  _volume = val;
                                                  _isMuted = val == 0.0;
                                                  _controller?.setVolume(val);
                                                  _showVolumeHud = true;
                                                });
                                                _volumeHudTimer?.cancel();
                                                _volumeHudTimer = Timer(const Duration(milliseconds: 1600), () {
                                                  if (mounted) setState(() => _showVolumeHud = false);
                                                });
                                                _hideControlsTimer?.cancel();
                                              },
                                              onChangeEnd: (_) => _startHideControlsTimer(),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${((_isMuted ? 0.0 : _volume) * 100).toInt()}%',
                                          style: TextStyle(
                                            color: _isMuted ? Colors.redAccent : Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),

                                    const Spacer(),

                                    // Fit label
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: _cycleVideoFit,
                                        child: Tooltip(
                                          message: 'Cycle Aspect Ratio (F)',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _videoFit.name.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Channels / Feeds Side Drawer
                if (_showSourcesDrawer)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: 360,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xF2080A10),
                        border: Border(left: BorderSide(color: Color(0xFF1E2336), width: 1.2)),
                        boxShadow: [
                          BoxShadow(color: Colors.black87, blurRadius: 24, offset: Offset(-6, 0)),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCategoryList ? Icons.format_list_bulleted_rounded : Icons.tune_rounded,
                                color: const Color(0xFF7C5CFF),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.categoryTitle ?? (isCategoryList ? 'Category Channels' : 'Stream Feeds'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${widget.hits.length}',
                                  style: const TextStyle(
                                    color: Color(0xFF9D4EDD),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                                onPressed: () => setState(() => _showSourcesDrawer = false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              controller: _sourcesScrollController,
                              itemCount: widget.hits.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final hit = widget.hits[index];
                                final isSelected = index == _activeHitIndex;
                                final numFormatted = (index + 1).toString().padLeft(3, '0');

                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _switchSource(index),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 120),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF7C5CFF).withValues(alpha: 0.25)
                                            : Colors.white.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF7C5CFF)
                                              : Colors.white.withValues(alpha: 0.08),
                                          width: isSelected ? 1.4 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Number
                                          SizedBox(
                                            width: 28,
                                            child: Text(
                                              numFormatted,
                                              style: TextStyle(
                                                color: isSelected ? const Color(0xFF00E5FF) : Colors.white30,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 6),

                                          // Icon / Logo
                                          Container(
                                            width: 38,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF080A10),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFF1E2336)),
                                            ),
                                            child: hit.stream.icon.isNotEmpty
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(3),
                                                    child: CachedNetworkImage(
                                                      imageUrl: hit.stream.icon,
                                                      fit: BoxFit.contain,
                                                      memCacheWidth: 64,
                                                      errorWidget: (_, _, _) => Icon(
                                                        isLive ? Icons.live_tv_rounded : Icons.movie_rounded,
                                                        color: Colors.white38,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  )
                                                : Icon(
                                                    isLive ? Icons.live_tv_rounded : Icons.movie_rounded,
                                                    color: Colors.white38,
                                                    size: 16,
                                                  ),
                                          ),

                                          const SizedBox(width: 10),

                                          // Channel Title
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  hit.stream.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white : Colors.white70,
                                                    fontSize: 13,
                                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  hit.portal.portal.username.isNotEmpty
                                                      ? hit.portal.portal.username
                                                      : hit.portal.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.4),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          if (isSelected) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF7C5CFF).withValues(alpha: 0.3),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Color(0xFF00E5FF),
                                                size: 16,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  if (duration.inHours > 0) {
    return '${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds';
  }
  return '$twoDigitMinutes:$twoDigitSeconds';
}

class _IptvCustomProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  const _IptvCustomProgressBar({
    required this.controller,
    this.onSeekStart,
    this.onSeekEnd,
  });

  @override
  State<_IptvCustomProgressBar> createState() => _IptvCustomProgressBarState();
}

class _IptvCustomProgressBarState extends State<_IptvCustomProgressBar> {
  double? _hoverX;
  bool _isDragging = false;
  Duration? _dragPosition;

  void _seekTo(double x, double width, Duration totalDuration) {
    if (width <= 0 || totalDuration <= Duration.zero) return;
    final percent = (x / width).clamp(0.0, 1.0);
    final position = totalDuration * percent;
    widget.controller.seekTo(position);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, VideoPlayerValue value, child) {
        final duration = value.duration;
        final position = _isDragging
            ? (_dragPosition ?? value.position)
            : value.position;
        final buffered = value.buffered;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onHover: (event) {
                setState(() {
                  _hoverX = event.localPosition.dx.clamp(0.0, width);
                });
              },
              onExit: (event) {
                setState(() {
                  _hoverX = null;
                });
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) {
                  widget.onSeekStart?.call();
                  setState(() {
                    _isDragging = true;
                    _hoverX = details.localPosition.dx.clamp(0.0, width);
                    if (duration > Duration.zero) {
                      _dragPosition = duration * (_hoverX! / width);
                    }
                  });
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _hoverX = details.localPosition.dx.clamp(0.0, width);
                    if (duration > Duration.zero) {
                      _dragPosition = duration * (_hoverX! / width);
                    }
                  });
                },
                onHorizontalDragEnd: (details) {
                  if (_dragPosition != null) {
                    widget.controller.seekTo(_dragPosition!);
                  }
                  setState(() {
                    _isDragging = false;
                    _dragPosition = null;
                  });
                  widget.onSeekEnd?.call();
                },
                onTapDown: (details) {
                  _seekTo(details.localPosition.dx, width, duration);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      // Invisible hit target
                      Container(
                        height: 24,
                        width: double.infinity,
                        color: Colors.transparent,
                      ),

                      // Background Bar
                      Container(
                        height: 5,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),

                      // Buffered Bar
                      for (final range in buffered)
                        if (duration.inMilliseconds > 0)
                          Positioned(
                            left: (width * (range.start.inMilliseconds / duration.inMilliseconds)).clamp(0.0, width),
                            child: Container(
                              height: 5,
                              width: (width * ((range.end.inMilliseconds - range.start.inMilliseconds) / duration.inMilliseconds)).clamp(0.0, width),
                              decoration: BoxDecoration(
                                color: Colors.white38,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),

                      // Played Bar
                      Container(
                        height: 5,
                        width: duration.inMilliseconds > 0
                            ? (width * (position.inMilliseconds / duration.inMilliseconds)).clamp(0.0, width)
                            : 0,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C5CFF), Color(0xFF00D2EF)],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),

                      // Scrubber Handle
                      Positioned(
                        left: duration.inMilliseconds > 0
                            ? (width * (position.inMilliseconds / duration.inMilliseconds)).clamp(0.0, width) - 7
                            : -7,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C5CFF).withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Hover Tooltip
                      if (_hoverX != null && duration > Duration.zero)
                        Positioned(
                          left: (_hoverX! - 30).clamp(0.0, width - 60),
                          bottom: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C0E15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white24, width: 1),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Text(
                              _formatDuration(duration * (_hoverX! / width)),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
