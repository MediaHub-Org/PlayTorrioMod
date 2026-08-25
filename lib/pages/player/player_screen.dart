import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'package:playtorrio/models/movie/video.dart';
import 'package:playtorrio/models/movie/movie_detail.dart';
import 'package:playtorrio/models/subtitle/subtitle_model.dart';
import 'package:playtorrio/services/subtitles/subtitle_service.dart';
import 'package:playtorrio/services/subtitles/subtitle_parser.dart';
import 'package:playtorrio/services/subtitles/subtitle_sync_helper.dart';

import '../../models/stream/stream_model.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/debrid/debrid_service.dart';
import '../../services/stream/torrent_stream_service.dart';
import '../../services/stream/local_stream_proxy.dart';
import '../../services/glass_settings.dart';
import '../../services/trakt/trakt_service.dart';
import '../../services/simkl/simkl_service.dart';

import '../../widgets/player/player_glass.dart';
import '../../widgets/player/player_top_bar.dart';
import '../../widgets/player/player_transport.dart';
import '../../widgets/player/player_speed_menu.dart';
import '../../services/window/window_service.dart';
import '../../widgets/player/player_aspect_menu.dart';
import '../../widgets/player/player_audio_menu.dart';
import '../../widgets/player/player_subtitle_menu.dart';
import '../../widgets/player/player_sub_style_bar.dart';
import '../../widgets/player/sub_sync_bar.dart';
import '../../widgets/player/text_sync_overlay.dart';

class PlayerScreen extends StatefulWidget {
  final StreamSource source;
  final String title;
  final String? backdropUrl;
  final String? logoUrl;
  final MovieDetail? detail;
  final Video? episode;
  final Duration? initialPosition;

  const PlayerScreen({
    super.key,
    required this.source,
    required this.title,
    this.backdropUrl,
    this.logoUrl,
    this.detail,
    this.episode,
    this.initialPosition,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String _statusMessage = 'Initializing...';
  bool _showControls = true;
  bool _isHoveringUI = false;
  Timer? _hideTimer;
  Timer? _progressSaveTimer;
  DateTime? _lastPointerTimerReset;
  late AnimationController _logoAnimController;

  // Active Menu / Popover
  String? _activeMenu; // 'subtitle' | 'audio' | 'speed' | 'aspect' | 'style' | null
  bool _showSubSyncBar = false;
  bool _showTextSyncOverlay = false;

  // Playback & Audio State
  double _volume = 1.0;
  double _lastVolumeBeforeMute = 1.0;
  bool _isMuted = false;
  double _playbackRate = 1.0;
  BoxFit _videoFit = BoxFit.contain;
  List<PlayerAudioTrack> _audioTracks = [];
  int _selectedAudioTrackIndex = 0;
  double _audioDelaySec = 0.0;

  // Subtitle State
  List<SubtitleLanguageGroup> _subtitleGroups = [];
  SubtitleVariant? _currentSubtitleVariant;
  bool _isSubtitleEnabled = false;
  String? _currentSubtitlePath;
  List<SubCue> _currentCues = [];
  SubFormat _currentSubFormat = SubFormat.srt;
  double _subtitleDelayMs = 0;
  double _subtitleScale = 1.0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _logoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initStream();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _initStream() async {
    String? streamUrl;

    print('[PlayerScreen] Initializing playback:');
    print('[PlayerScreen]   Title: ${widget.title}');
    print('[PlayerScreen]   Source Name: ${widget.source.name}');
    print('[PlayerScreen]   Addon Name: ${widget.source.addonName}');
    print('[PlayerScreen]   Source Title: ${widget.source.title}');
    print('[PlayerScreen]   Raw URL: ${widget.source.url}');

    try {
      final rawUrl = widget.source.url;
      final infoHash = widget.source.infoHash;
      final isMagnetUrl = rawUrl != null && rawUrl.startsWith('magnet:');
      final isTorrent = (infoHash != null && infoHash.isNotEmpty) || isMagnetUrl;

      if (isTorrent) {
        String magnet;
        if (isMagnetUrl) {
          magnet = rawUrl;
        } else {
          magnet = 'magnet:?xt=urn:btih:$infoHash';
          if (widget.source.sources != null) {
            for (final source in widget.source.sources!) {
              if (source.startsWith('tracker:')) {
                final trackerUrl = source.replaceFirst('tracker:', '');
                magnet += '&tr=${Uri.encodeComponent(trackerUrl)}';
              }
            }
          }
        }

        final useDebrid = await DebridService().isDebridActiveForStreams();
        if (useDebrid) {
          final activeService = await DebridService().getSelectedService();
          if (!mounted) return;
          setState(() => _statusMessage = 'Resolving via $activeService cloud...');

          final seasonNum = widget.episode?.season;
          final episodeNum = widget.episode?.episode;

          final debridFiles = await DebridService().resolveMagnet(
            magnet: magnet,
            fileIndex: widget.source.fileIdx,
            filename: widget.title,
            season: seasonNum,
            episode: episodeNum,
          );

          if (debridFiles.isEmpty || debridFiles.first.downloadUrl.isEmpty) {
            throw Exception('$activeService returned no direct stream links.');
          }

          streamUrl = debridFiles.first.downloadUrl;
          print('[PlayerScreen] Debrid resolved stream URL: $streamUrl');
        } else {
          if (!mounted) return;
          setState(() => _statusMessage = 'Gathering metadata & peers...');

          streamUrl = await TorrentStreamService().streamTorrent(
            magnet,
            fileIdx: widget.source.fileIdx,
          );
        }
      } else if (rawUrl != null && rawUrl.isNotEmpty) {
        streamUrl = rawUrl;
      } else {
        throw Exception('No valid stream source found.');
      }

      if (streamUrl == null) throw Exception('Stream URL is null');

      final sanitizedUrlStr = streamUrl.contains('::')
          ? streamUrl.replaceAll('::', '%3A%3A')
          : streamUrl;

      final playerHeaders = <String, String>{};
      if (sanitizedUrlStr.contains('hakunaymatata.com')) {
        playerHeaders['User-Agent'] = 'Lavf/60.16.100';
      } else {
        playerHeaders['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      }
      if (widget.source.headers != null) {
        playerHeaders.addAll(widget.source.headers!);
      }

      final lowerUrl = sanitizedUrlStr.toLowerCase();
      final isDirectVideo = lowerUrl.contains('.mp4') ||
          lowerUrl.contains('.mkv') ||
          lowerUrl.contains('.avi') ||
          lowerUrl.contains('.webm');

      // Direct native path for MP4/MKV files; use proxy for HLS / M3U8 playlists requiring manifest rewrite
      final needsProxy = widget.source.headers != null &&
          widget.source.headers!.isNotEmpty &&
          !isDirectVideo;

      String resolvedUrlStr = needsProxy
          ? LocalStreamProxy.instance.getProxiedUrl(sanitizedUrlStr, playerHeaders)
          : sanitizedUrlStr;

      var cleanUri = Uri.parse(resolvedUrlStr);
      print('[PlayerScreen] Attempting to open network stream URL: $cleanUri');

      if (!mounted) return;
      setState(() => _statusMessage = 'Buffering video...');

      _controller = VideoPlayerController.networkUrl(
        cleanUri,
        httpHeaders: playerHeaders,
      );
      _controller!.addListener(_onControllerError);

      try {
        await _controller!.initialize();
      } catch (initErr) {
        // Fallback: If direct playback failed with custom headers, try through LocalStreamProxy
        if (!needsProxy && widget.source.headers != null && widget.source.headers!.isNotEmpty) {
          print('[PlayerScreen] Direct playback failed, falling back to LocalStreamProxy: $initErr');
          resolvedUrlStr = LocalStreamProxy.instance.getProxiedUrl(sanitizedUrlStr, playerHeaders);
          cleanUri = Uri.parse(resolvedUrlStr);
          _controller?.removeListener(_onControllerError);
          _controller?.dispose();

          _controller = VideoPlayerController.networkUrl(
            cleanUri,
            httpHeaders: playerHeaders,
          );
          _controller!.addListener(_onControllerError);
          await _controller!.initialize();
        } else {
          rethrow;
        }
      }

      _setSubtitleScale(_subtitleScale);

      if (widget.initialPosition != null && widget.initialPosition! > Duration.zero) {
        print('[PlayerScreen] Seeking to saved position: ${widget.initialPosition}');
        await _controller!.seekTo(widget.initialPosition!);
      }

      print('[PlayerScreen SUCCESS] Video controller initialized successfully for $streamUrl');

      // Fetch initial media tracks
      try {
        final mediaInfo = _controller?.getMediaInfo();
        final audioList = mediaInfo?.audio;
        if (audioList != null && audioList.isNotEmpty) {
          _audioTracks = audioList.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final lang = item.metadata['language'] ?? item.metadata['lang'];
            final title = item.metadata['title'] ??
                (lang != null ? lang.toUpperCase() : 'Track ${idx + 1}');
            final codec = item.codec.codec;
            return PlayerAudioTrack(
              index: idx,
              title: title,
              language: lang,
              codec: codec,
              channels: item.codec.channels,
            );
          }).toList();
        }
      } catch (_) {}

      // Pre-fetch subtitles in background
      _fetchInitialSubtitles();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      _controller!.play();
      _startHideControlsTimer();

      // Cloud Scrobble Start
      final detail = widget.detail;
      if (detail != null) {
        final targetId = detail.id.startsWith('tt') ? detail.id : (detail.tmdbId ?? detail.id);
        if (targetId.isNotEmpty) {
          final s = widget.episode?.season;
          final e = widget.episode?.episode;
          final initPos = widget.initialPosition?.inSeconds ?? 0;
          final dur = _controller!.value.duration.inSeconds;
          final progress = (dur > 0 ? (initPos / dur) * 100.0 : 0.0).clamp(0.0, 100.0);

          TraktService.instance.isAuthenticated().then((authed) {
            if (authed) {
              TraktService.instance.scrobbleStart(targetId, progress, season: s, episode: e);
            }
          });
          SimklService.instance.isAuthenticated().then((authed) {
            if (authed) {
              SimklService.instance.scrobbleStart(targetId, progress, season: s, episode: e);
            }
          });
        }
      }

      _progressSaveTimer?.cancel();
      _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _savePlaybackProgress();
      });
    } catch (e, stackTrace) {
      print('[PlayerScreen ERROR] Failed to initialize stream URL: "$streamUrl"');
      print('[PlayerScreen ERROR] Exception: $e');
      print('[PlayerScreen ERROR] StackTrace:\n$stackTrace');

      if (!mounted) return;

      String displayMessage = 'Error: $e';
      if (e is PlatformException &&
          (e.message?.contains('invalid or unsupported media') ?? false)) {
        displayMessage =
            'Media Open Error: Stream server quota exceeded or invalid media format.\nPlease select another stream.';
      }

      setState(() {
        _statusMessage = displayMessage;
      });
    }
  }

  Future<void> _fetchInitialSubtitles() async {
    try {
      int? searchYear;
      if (widget.detail?.year != null && widget.detail!.year!.isNotEmpty) {
        final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(widget.detail!.year!);
        if (yMatch != null) searchYear = int.tryParse(yMatch.group(1)!);
      }
      final groups = await SubtitleService().fetchAllSubtitles(
        widget.detail?.name ?? widget.title,
        imdbId: widget.detail?.id,
        season: widget.episode?.season,
        episode: widget.episode?.episode,
        year: searchYear,
      );
      if (mounted && groups.isNotEmpty) {
        setState(() => _subtitleGroups = groups);
      }
    } catch (_) {}
  }

  void _startHideControlsTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted &&
          _controller != null &&
          _controller!.value.isPlaying &&
          !_isHoveringUI &&
          _activeMenu == null &&
          !_showSubSyncBar &&
          !_showTextSyncOverlay) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (_showTextSyncOverlay || _activeMenu != null) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  void _handlePointerActivity() {
    if (_isLoading) return;
    if (!_showControls) setState(() => _showControls = true);

    final now = DateTime.now();
    if (_lastPointerTimerReset == null ||
        now.difference(_lastPointerTimerReset!) >= const Duration(milliseconds: 250)) {
      _lastPointerTimerReset = now;
      _startHideControlsTimer();
    }
  }

  void _toggleMenu(String menuName) {
    setState(() {
      if (_activeMenu == menuName) {
        _activeMenu = null;
        _startHideControlsTimer();
      } else {
        _activeMenu = menuName;
        _showSubSyncBar = false;
        _showTextSyncOverlay = false;
        _hideTimer?.cancel();
      }
    });
  }

  Future<void> _loadSubtitle(SubtitleVariant variant) async {
    _currentSubtitleVariant = variant;
    _isSubtitleEnabled = true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${variant.language} subtitle...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final path = await SubtitleService().downloadSubtitle(variant);
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download subtitle')),
        );
      }
      return;
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final content = SubtitleParser.decodeBytesWithFallback(bytes);
        final parseResult = SubtitleParser.parse(content);
        _currentCues = parseResult.cues;
        _currentSubFormat = parseResult.format;
      }
    } catch (e) {
      print('[PlayerScreen] Subtitle cues parse error: $e');
    }

    if (_controller != null) {
      _currentSubtitlePath = path;
      if (_subtitleDelayMs != 0) {
        await _applyLiveDelay(_subtitleDelayMs / 1000.0);
      } else {
        _controller!.setExternalSubtitle(path);
      }
      _setSubtitleScale(_subtitleScale);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${variant.language} subtitle loaded (${_currentCues.length} lines)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _setSubtitleScale(double scale) {
    final clamped = scale.clamp(0.5, 3.0);
    setState(() => _subtitleScale = clamped);

    final s = clamped.toStringAsFixed(2);
    final size = (32 * clamped).round().toString();

    _controller?.setProperty('sub-scale', s);
    _controller?.setProperty('subtitle.scale', s);
    _controller?.setProperty('sub-font-size', size);
    _controller?.setProperty('sub-ass-override', 'scale');
    _controller?.setProperty('sub-ass-force-margins', 'yes');
    _controller?.setProperty('sub-use-margins', 'yes');
  }

  Future<void> _applyLiveDelay(double delaySec) async {
    _subtitleDelayMs = delaySec * 1000.0;
    if (_currentSubtitlePath != null && _controller != null) {
      if (_currentCues.isNotEmpty) {
        final syncedCues = SubtitleSyncHelper.applyLinearSync(
          cues: _currentCues,
          points: [],
          nudge: delaySec,
        );
        final content = _currentSubFormat == SubFormat.vtt
            ? SubtitleParser.toVtt(syncedCues)
            : SubtitleParser.toSrt(syncedCues);
        final ext = _currentSubFormat == SubFormat.vtt ? 'vtt' : 'srt';
        final newPath = _currentSubtitlePath!.replaceAll(
          RegExp(r'\.(srt|vtt)$', caseSensitive: false),
          '_delayed.$ext',
        );
        await File(newPath).writeAsString(content);
        _controller!.setExternalSubtitle(newPath);
      } else {
        final newPath = await _shiftSubtitleTime(_currentSubtitlePath!, _subtitleDelayMs);
        _controller!.setExternalSubtitle(newPath);
      }
    }
  }

  Future<void> _saveTextSyncedCues(List<SubCue> syncedCues, double offsetSec) async {
    _currentCues = syncedCues;
    _subtitleDelayMs = offsetSec * 1000.0;
    if (_currentSubtitlePath != null && _controller != null) {
      final content = _currentSubFormat == SubFormat.vtt
          ? SubtitleParser.toVtt(syncedCues)
          : SubtitleParser.toSrt(syncedCues);
      final ext = _currentSubFormat == SubFormat.vtt ? 'vtt' : 'srt';
      final newPath = _currentSubtitlePath!.replaceAll(
        RegExp(r'\.(srt|vtt)$', caseSensitive: false),
        '_synced.$ext',
      );
      await File(newPath).writeAsString(content);
      _currentSubtitlePath = newPath;
      _controller!.setExternalSubtitle(newPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subtitle timing synchronized and saved!')),
        );
      }
    }
  }

  Future<String> _shiftSubtitleTime(String originalPath, double delayMs) async {
    final file = File(originalPath);
    if (!await file.exists()) return originalPath;

    final content = await file.readAsString();
    final delay = delayMs.toInt();
    if (delay == 0) return originalPath;

    final regex = RegExp(r'(\d{2}):(\d{2}):(\d{2})([,.])(\d{3})');
    final newContent = content.replaceAllMapped(regex, (match) {
      final hours = int.parse(match.group(1)!);
      final minutes = int.parse(match.group(2)!);
      final seconds = int.parse(match.group(3)!);
      final sep = match.group(4)!;
      final ms = int.parse(match.group(5)!);

      var totalMs = (hours * 3600000) + (minutes * 60000) + (seconds * 1000) + ms + delay;
      if (totalMs < 0) totalMs = 0;

      final newHours = (totalMs ~/ 3600000).toString().padLeft(2, '0');
      final newMinutes = ((totalMs % 3600000) ~/ 60000).toString().padLeft(2, '0');
      final newSeconds = ((totalMs % 60000) ~/ 1000).toString().padLeft(2, '0');
      final newMs = (totalMs % 1000).toString().padLeft(3, '0');

      return '$newHours:$newMinutes:$newSeconds$sep$newMs';
    });

    final newPath = originalPath
        .replaceAll('.srt', '_delayed.srt')
        .replaceAll('.vtt', '_delayed.vtt');
    final newFile = File(newPath);
    await newFile.writeAsString(newContent);
    return newPath;
  }

  void _onControllerError() {
    if (!mounted || _controller == null) return;
    final value = _controller!.value;
    if (value.hasError && !_isLoading) {
      final errorMsg = value.errorDescription ?? 'Unknown playback error';
      print('[PlayerScreen ERROR] Video controller error: $errorMsg');
      setState(() {
        _isLoading = true;
        _statusMessage = 'Playback error: $errorMsg';
      });
    }
  }

  void _savePlaybackProgress() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (widget.detail == null) return;

    final pos = _controller!.value.position.inSeconds;
    final dur = _controller!.value.duration.inSeconds;
    if (dur <= 0) return;

    ContinueWatchingService.saveProgress(
      detail: widget.detail!,
      episode: widget.episode,
      source: widget.source,
      positionSeconds: pos,
      totalDurationSeconds: dur,
    );
  }

  @override
  void dispose() {
    _progressSaveTimer?.cancel();
    _savePlaybackProgress();
    WakelockPlus.disable();
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller?.removeListener(_onControllerError);
    _controller?.dispose();
    _logoAnimController.dispose();
    TorrentStreamService().cleanup();
    WindowService.instance.exitFullscreen();
    super.dispose();
  }

  DateTime? _lastScreenTapTime;

  void _handleScreenTap() {
    final now = DateTime.now();
    if (_lastScreenTapTime != null &&
        now.difference(_lastScreenTapTime!) < const Duration(milliseconds: 280)) {
      _lastScreenTapTime = null;
      WindowService.instance.toggleFullscreen();
    } else {
      _lastScreenTapTime = now;
      _toggleControls();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        WindowService.instance.exitFullscreen();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          cursor: (_showControls || _isLoading || _activeMenu != null)
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          onHover: (_) => _handlePointerActivity(),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _handleScreenTap,
            child: _buildPlayerBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundStack() {
    return Stack(
      children: [
        // Loading Backdrop
        if (_isLoading && widget.backdropUrl != null)
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.network(widget.backdropUrl!, fit: BoxFit.cover),
            ),
          ),

        // Video Player
        Center(
          child: _isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.logoUrl != null)
                      AnimatedBuilder(
                        animation: _logoAnimController,
                        builder: (context, child) {
                          final val = _logoAnimController.value;
                          return Opacity(
                            opacity: 0.3 + (val * 0.7),
                            child: Transform.scale(
                              scale: 0.95 + (val * 0.1),
                              child: child,
                            ),
                          );
                        },
                        child: Image.network(
                          widget.logoUrl!,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      const CircularProgressIndicator(color: PlayerTheme.accent),
                    const SizedBox(height: 32),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                )
              : SizedBox.expand(
                  child: FittedBox(
                    fit: _videoFit,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildControlsOverlay() {
    final buffered = _controller?.value.buffered.isNotEmpty == true
        ? _controller!.value.buffered.last.end
        : null;

    final episodeTitle = widget.episode?.title;
    final episodeSubtitle = widget.episode != null
        ? 'S${widget.episode!.season}:E${widget.episode!.episode}${episodeTitle != null && episodeTitle.isNotEmpty ? " • $episodeTitle" : ""}'
        : widget.detail?.year;

    return Stack(
      children: [
        // Outside Tap Barrier to dismiss active floating menu
        if (_activeMenu != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _activeMenu = null),
              child: Container(color: Colors.transparent),
            ),
          ),

        // Top Header Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: (!_showControls && !_isLoading) || _showSubSyncBar || _showTextSyncOverlay,
            child: AnimatedOpacity(
              opacity: (_showControls || _isLoading) && !_showSubSyncBar && !_showTextSyncOverlay
                  ? 1.0
                  : 0.0,
              duration: const Duration(milliseconds: 200),
              child: MouseRegion(
                onEnter: (_) {
                  _isHoveringUI = true;
                  _hideTimer?.cancel();
                },
                onExit: (_) {
                  _isHoveringUI = false;
                  _startHideControlsTimer();
                },
                child: PlayerTopBar(
                  title: widget.detail?.name ?? widget.title,
                  subtitle: episodeSubtitle,
                  quality: widget.source.name,
                  onBack: () {
                    WindowService.instance.exitFullscreen();
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),
        ),

          // Bottom Transport Bar
          if (!_isLoading && _controller != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: (!_showControls && _activeMenu == null) || _showTextSyncOverlay,
                child: AnimatedOpacity(
                  opacity: (_showControls || _activeMenu != null) && !_showTextSyncOverlay ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: MouseRegion(
                    onEnter: (_) {
                      _isHoveringUI = true;
                      _hideTimer?.cancel();
                    },
                    onExit: (_) {
                      _isHoveringUI = false;
                      _startHideControlsTimer();
                    },
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller!,
                      builder: (context, value, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: WindowService.instance.isFullscreenNotifier,
                          builder: (context, isFs, _) {
                            return PlayerTransport(
                              isPlaying: value.isPlaying,
                              position: value.position,
                              duration: value.duration,
                              buffered: buffered,
                              volume: _volume,
                              isMuted: _isMuted || _volume == 0,
                              playbackRate: _playbackRate,
                              isSubtitlesActive: _isSubtitleEnabled && _currentSubtitleVariant != null,
                              isSubSyncActive: _showSubSyncBar || _subtitleDelayMs != 0,
                              isAudioActive: _selectedAudioTrackIndex > 0,
                              isFullscreen: isFs,
                              onPlayPause: () {
                                setState(() {
                                  if (_controller!.value.isPlaying) {
                                    _controller!.pause();
                                  } else {
                                    _controller!.play();
                                  }
                                });
                                _startHideControlsTimer();
                              },
                              onSeek: (pos) => _controller!.seekTo(pos),
                              onSeekBack10: () {
                                final pos = _controller!.value.position;
                                _controller!.seekTo(pos - const Duration(seconds: 10));
                                _startHideControlsTimer();
                              },
                              onSeekForward10: () {
                                final pos = _controller!.value.position;
                                _controller!.seekTo(pos + const Duration(seconds: 10));
                                _startHideControlsTimer();
                              },
                              onVolumeChanged: (vol) {
                                setState(() {
                                  _volume = vol;
                                  _isMuted = vol == 0;
                                });
                                _controller!.setVolume(vol.clamp(0.0, 1.0));
                              },
                              onToggleMute: () {
                                if (_volume > 0) {
                                  _lastVolumeBeforeMute = _volume;
                                  _controller!.setVolume(0.0);
                                  setState(() {
                                    _volume = 0.0;
                                    _isMuted = true;
                                  });
                                } else {
                                  final restore = _lastVolumeBeforeMute > 0 ? _lastVolumeBeforeMute : 1.0;
                                  _controller!.setVolume(restore.clamp(0.0, 1.0));
                                  setState(() {
                                    _volume = restore;
                                    _isMuted = false;
                                  });
                                }
                              },
                              onToggleAspectMenu: () => _toggleMenu('aspect'),
                              onToggleSpeedMenu: () => _toggleMenu('speed'),
                              onToggleAudioMenu: () => _toggleMenu('audio'),
                              onToggleSubtitleMenu: () => _toggleMenu('subtitle'),
                              onToggleSubSync: () {
                                setState(() {
                                  _showSubSyncBar = !_showSubSyncBar;
                                  _activeMenu = null;
                                });
                              },
                              onToggleFullscreen: () => WindowService.instance.toggleFullscreen(),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

          // Floating Subtitle Menu Popover
          if (_activeMenu == 'subtitle' && !_isLoading)
            Positioned(
              bottom: MediaQuery.sizeOf(context).width < 680 ? 76 : 96,
              right: MediaQuery.sizeOf(context).width < 680 ? 16 : 28,
              child: PlayerSubtitleMenu(
                groups: _subtitleGroups,
                selectedVariant: _currentSubtitleVariant,
                isSubtitleEnabled: _isSubtitleEnabled,
                movieTitle: widget.detail?.name ?? widget.title,
                imdbId: widget.detail?.id,
                season: widget.episode?.season,
                episode: widget.episode?.episode,
                year: widget.detail?.year != null ? int.tryParse(widget.detail!.year!) : null,
                delaySec: _subtitleDelayMs / 1000.0,
                onSelectVariant: (v) {
                  if (v != null) _loadSubtitle(v);
                },
                onToggleOff: () {
                  setState(() {
                    _isSubtitleEnabled = false;
                    _currentSubtitleVariant = null;
                  });
                  _controller?.setExternalSubtitle('');
                },
                onOpenSyncBar: () {
                  setState(() {
                    _activeMenu = null;
                    _showSubSyncBar = true;
                  });
                },
                onOpenStyleBar: () {
                  setState(() => _activeMenu = 'style');
                },
                onOpenTextSync: () {
                  setState(() {
                    _activeMenu = null;
                    _showTextSyncOverlay = true;
                  });
                },
                onClose: () => setState(() => _activeMenu = null),
              ),
            ),

          // Floating Audio Menu Popover
          if (_activeMenu == 'audio' && !_isLoading)
            Positioned(
              bottom: MediaQuery.sizeOf(context).width < 680 ? 76 : 96,
              right: MediaQuery.sizeOf(context).width < 680 ? 16 : 28,
              child: PlayerAudioMenu(
                audioTracks: _audioTracks,
                selectedIndex: _selectedAudioTrackIndex,
                delaySec: _audioDelaySec,
                onTrackSelected: (idx) {
                  setState(() => _selectedAudioTrackIndex = idx);
                  _controller?.setAudioTracks([idx]);
                },
                onDelayChanged: (sec) {
                  setState(() => _audioDelaySec = sec);
                  _controller?.setProperty('audio-delay', sec.toString());
                },
                onClose: () => setState(() => _activeMenu = null),
              ),
            ),

          // Floating Speed Menu Popover
          if (_activeMenu == 'speed' && !_isLoading)
            Positioned(
              bottom: MediaQuery.sizeOf(context).width < 680 ? 76 : 96,
              right: MediaQuery.sizeOf(context).width < 680 ? 16 : 28,
              child: PlayerSpeedMenu(
                currentRate: _playbackRate,
                onRateSelected: (rate) {
                  setState(() => _playbackRate = rate);
                  _controller?.setPlaybackSpeed(rate);
                },
                onClose: () => setState(() => _activeMenu = null),
              ),
            ),

          // Floating Aspect Ratio Popover
          if (_activeMenu == 'aspect' && !_isLoading)
            Positioned(
              bottom: MediaQuery.sizeOf(context).width < 680 ? 76 : 96,
              right: MediaQuery.sizeOf(context).width < 680 ? 16 : 28,
              child: PlayerAspectMenu(
                currentFit: _videoFit,
                subtitleScale: _subtitleScale,
                onFitSelected: (fit) => setState(() => _videoFit = fit),
                onSubtitleScaleChanged: _setSubtitleScale,
                onClose: () => setState(() => _activeMenu = null),
              ),
            ),

          // Top Floating Subtitle Appearance Toolbar
          if (_activeMenu == 'style' && !_isLoading)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              left: 0,
              right: 0,
              child: PlayerSubStyleBar(
                scale: _subtitleScale,
                onScaleChanged: _setSubtitleScale,
                onClose: () => setState(() => _activeMenu = null),
              ),
            ),

          // Top Floating Live SubSyncBar
          if (_showSubSyncBar && !_isLoading)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              left: 0,
              right: 0,
              child: SubSyncBar(
                delaySec: _subtitleDelayMs / 1000.0,
                isTextSyncAvailable: _currentSubtitlePath != null && _currentCues.isNotEmpty,
                onDelayChanged: (sec) => _applyLiveDelay(sec),
                onEnterTextSync: () {
                  setState(() {
                    _showSubSyncBar = false;
                    _showTextSyncOverlay = true;
                  });
                },
                onClose: () {
                  setState(() => _showSubSyncBar = false);
                  _startHideControlsTimer();
                },
              ),
            ),

          // Right Drawer Text Sync
          if (_showTextSyncOverlay && !_isLoading && _controller != null && _currentCues.isNotEmpty)
            Positioned.fill(
              child: TextSyncOverlay(
                controller: _controller!,
                initialCues: _currentCues,
                baseOffsetSec: _subtitleDelayMs / 1000.0,
                onClose: () {
                  setState(() => _showTextSyncOverlay = false);
                  _startHideControlsTimer();
                },
                onSave: _saveTextSyncedCues,
              ),
            ),
        ],
      );
  }

  Widget _buildPlayerBody() {
    return ValueListenableBuilder<bool>(
      valueListenable: GlassSettings.enabled,
      builder: (context, enabled, _) {
        if (enabled) {
          return LiquidGlassView(
            realTimeCapture: _showControls && !_isLoading,
            useSync: true,
            pixelRatio: 0.85,
            refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
            regionCapture: true,
            backgroundWidget: _buildBackgroundStack(),
            child: _buildControlsOverlay(),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: _buildBackgroundStack()),
            RepaintBoundary(child: _buildControlsOverlay()),
          ],
        );
      },
    );
  }
}
