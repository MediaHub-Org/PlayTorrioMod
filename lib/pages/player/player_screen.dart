import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
import '../../services/theme/glass_settings.dart';
import '../../services/trakt/trakt_service.dart';
import '../../services/simkl/simkl_service.dart';
import '../../services/player/player_settings.dart';

import '../../widgets/player/player_glass.dart';
import '../../widgets/player/player_top_bar.dart';
import '../../widgets/player/player_transport.dart';
import '../../widgets/player/player_speed_menu.dart';
import '../../services/window/window_service.dart';
import '../../models/player/skip_segment_model.dart';
import '../../services/player/skip_segments_service.dart';
import '../../widgets/player/player_aspect_menu.dart';
import '../../widgets/player/player_audio_menu.dart';
import '../../widgets/player/player_subtitle_menu.dart';
import '../../widgets/player/player_sub_style_bar.dart';
import '../../widgets/player/player_skip_button.dart';
import '../../widgets/player/player_episodes_panel.dart';
import '../../widgets/player/player_sources_panel.dart';
import '../../widgets/player/player_volume_control.dart';
import '../../widgets/player/sub_sync_bar.dart';
import '../../widgets/player/text_sync_overlay.dart';
import '../../models/download/download_task_model.dart';
import '../../services/download/download_service.dart';
import '../../utils/download/download_path_helper.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

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
  bool _wasBuffering = false;
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
  bool _showVolumeHud = false;
  Timer? _volumeHudTimer;
  double _playbackRate = 1.0;
  BoxFit _videoFit = BoxFit.contain;
  List<PlayerAudioTrack> _audioTracks = [];
  int _selectedAudioTrackIndex = 0;
  double _audioDelaySec = 0.0;

  // Subtitle State
  List<SubtitleLanguageGroup> _subtitleGroups = [];
  List<PlayerEmbeddedSubtitle> _embeddedSubtitles = [];
  int? _selectedEmbeddedSubtitleIndex;
  SubtitleVariant? _currentSubtitleVariant;
  bool _isSubtitleEnabled = false;
  String? _currentSubtitlePath;
  List<SubCue> _currentCues = [];
  SubFormat _currentSubFormat = SubFormat.srt;
  double _subtitleDelayMs = 0;
  double _subtitleScale = 1.0;

  // Skip Segments State (IntroDB)
  List<MediaSkipSegment> _skipSegments = [];
  MediaSkipSegment? _activeSkipSegment;
  bool _showSkipButton = false;
  final Set<String> _dismissedSegmentKeys = {};

  // Episodes & Sources Side Panels State
  late StreamSource _currentSource;
  Video? _currentEpisode;
  late String _currentTitle;
  bool _showEpisodesPanel = false;
  bool _showSourcesPanel = false;
  Video? _sourcesEpisode;
  String? _sourcesErrorMessage;
  final Map<String, List<StreamSource>> _cachedSourcesByEpisode = {};

  @override
  void initState() {
    super.initState();
    _currentSource = widget.source;
    _currentEpisode = widget.episode;
    _currentTitle = widget.title;

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
    print('[PlayerScreen]   Title: $_currentTitle');
    print('[PlayerScreen]   Source Name: ${_currentSource.name}');
    print('[PlayerScreen]   Addon Name: ${_currentSource.addonName}');
    print('[PlayerScreen]   Source Title: ${_currentSource.title}');
    print('[PlayerScreen]   Raw URL: ${_currentSource.url}');

    try {
      final rawUrl = _currentSource.url;

      // Handle offline downloaded file playback directly
      if (rawUrl != null && (File(rawUrl).existsSync() || _currentSource.name == 'Downloaded')) {
        print('[PlayerScreen] Initializing offline local file playback: $rawUrl');
        final localFile = File(rawUrl);
        _controller = VideoPlayerController.file(localFile);
        _controller!.addListener(_onControllerError);
        _controller!.addListener(_onPlaybackTick);
        PlayerSettings.applyToController(_controller!);
        await _controller!.initialize();
        PlayerSettings.applyToController(_controller!);
        _controller!.play();
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final infoHash = _currentSource.infoHash;
      final isMagnetUrl = rawUrl != null && rawUrl.startsWith('magnet:');
      final isTorrent = (infoHash != null && infoHash.isNotEmpty) || isMagnetUrl;

      if (isTorrent) {
        String magnet;
        if (isMagnetUrl) {
          magnet = rawUrl;
        } else {
          magnet = 'magnet:?xt=urn:btih:$infoHash';
          if (_currentSource.sources != null) {
            for (final source in _currentSource.sources!) {
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
          setState(() => _statusMessage = 'Using $activeService for files...');

          final seasonNum = _currentEpisode?.season;
          final episodeNum = _currentEpisode?.episode;

          final debridFiles = await DebridService().resolveMagnet(
            magnet: magnet,
            fileIndex: _currentSource.fileIdx,
            filename: _currentTitle,
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
            fileIdx: _currentSource.fileIdx,
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
      if (_currentSource.headers != null) {
        playerHeaders.addAll(_currentSource.headers!);
      }

      final lowerUrl = sanitizedUrlStr.toLowerCase();
      final isDirectVideo = lowerUrl.contains('.mp4') ||
          lowerUrl.contains('.mkv') ||
          lowerUrl.contains('.avi') ||
          lowerUrl.contains('.webm');

      // Direct native path for anime streams and direct videos with playerHeaders
      final isAnimeStream = _currentSource.addonName == 'MegaPlay' ||
          _currentSource.addonName == 'AniDB' ||
          _currentSource.addonName == 'WatchHentai' ||
          _currentSource.addonName == 'Hentaini' ||
          _currentSource.addonName == 'ArabicAnime' ||
          sanitizedUrlStr.contains('watching.onl') ||
          sanitizedUrlStr.contains('anidb.app');

      final needsProxy = !isAnimeStream &&
          !isDirectVideo &&
          (_currentSource.behaviorHints?['notWebReady'] == true &&
              _currentSource.headers != null &&
              _currentSource.headers!.isNotEmpty);

      String resolvedUrlStr = needsProxy
          ? LocalStreamProxy.instance.getProxiedUrl(sanitizedUrlStr, playerHeaders)
          : sanitizedUrlStr;

      var cleanUri = Uri.parse(resolvedUrlStr);
      print('[PlayerScreen] Attempting to open network stream URL: $cleanUri (headers: ${playerHeaders.keys})');

      if (!mounted) return;
      final epLabel = _currentEpisode != null
          ? 'S${_currentEpisode!.season ?? 1}:E${_currentEpisode!.episode ?? 1} - ${_currentEpisode!.title.isNotEmpty ? _currentEpisode!.title : "Episode ${_currentEpisode!.episode ?? 1}"}'
          : (widget.detail?.name ?? _currentTitle);
      setState(() => _statusMessage = 'Buffering $epLabel...');

      _controller = VideoPlayerController.networkUrl(
        cleanUri,
        httpHeaders: playerHeaders,
      );
      _controller!.addListener(_onControllerError);
      _controller!.addListener(_onPlaybackTick);
      PlayerSettings.applyToController(_controller!);

      try {
        await _controller!.initialize();
      } catch (initErr) {
        // Fallback: If direct playback failed with custom headers, try through LocalStreamProxy
        if (!needsProxy && _currentSource.headers != null && _currentSource.headers!.isNotEmpty) {
          print('[PlayerScreen] Direct playback failed, falling back to LocalStreamProxy: $initErr');
          resolvedUrlStr = LocalStreamProxy.instance.getProxiedUrl(sanitizedUrlStr, playerHeaders);
          cleanUri = Uri.parse(resolvedUrlStr);
          _controller?.removeListener(_onControllerError);
          _controller?.removeListener(_onPlaybackTick);
          _controller?.dispose();

          _controller = VideoPlayerController.networkUrl(
            cleanUri,
            httpHeaders: playerHeaders,
          );
          _controller!.addListener(_onControllerError);
          _controller!.addListener(_onPlaybackTick);
          PlayerSettings.applyToController(_controller!);
          await _controller!.initialize();
        } else {
          rethrow;
        }
      }

      PlayerSettings.applyToController(_controller!);

      _setSubtitleScale(_subtitleScale);
      _applyVolume(_isMuted ? 0.0 : _volume);

      // Fetch IntroDB skip segments in background
      _fetchSkipSegments();

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

        final subList = mediaInfo?.subtitle;
        if (subList != null && subList.isNotEmpty) {
          _embeddedSubtitles = subList.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final lang = item.metadata['language'] ?? item.metadata['lang'];
            final title = item.metadata['title'] ?? item.metadata['handler_name'] ??
                (lang != null ? lang.toUpperCase() : 'Track ${idx + 1}');
            final codec = item.codec.codec;
            return PlayerEmbeddedSubtitle(
              index: idx,
              title: title,
              language: lang,
              codec: codec,
            );
          }).toList();
          print('[PlayerScreen] Found ${_embeddedSubtitles.length} embedded subtitle tracks');
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
          final s = _currentEpisode?.season;
          final e = _currentEpisode?.episode;
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

      // If we have an episode context (TV show), reopen the sources panel with error notice!
      if (_currentEpisode != null && widget.detail?.videos.isNotEmpty == true) {
        setState(() {
          _isLoading = false;
          _showSourcesPanel = true;
          _sourcesEpisode = _currentEpisode;
          _sourcesErrorMessage = 'Source failed to play. Please select another source below.';
        });
        return;
      }

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

  static String cleanMediaTitle(String raw) {
    var name = raw;
    name = name.replaceAll(RegExp(r'\.(mkv|mp4|avi|webm|ts|mov|m4v|srt|vtt)$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'[._]'), ' ');
    name = name.replaceAll(RegExp(r'\b(2160p|1080p|720p|480p|4k|uhd|ds4k|webrip|web-dl|bluray|brrip|h264|x264|h265|x265|hevc|10bit|ddp5\.1|dd5\.1|atmos|aac|ac3|dts|flac|remux|hdr|dv|proper|repack|hdtv)\b', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'-[a-zA-Z0-9]+$'), '');
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _fetchInitialSubtitles() async {
    try {
      int? searchYear;
      if (widget.detail?.year != null && widget.detail!.year!.isNotEmpty) {
        final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(widget.detail!.year!);
        if (yMatch != null) searchYear = int.tryParse(yMatch.group(1)!);
      }
      final rawName = widget.detail?.name ?? widget.title;
      if (searchYear == null) {
        final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(rawName);
        if (yMatch != null) searchYear = int.tryParse(yMatch.group(1)!);
      }
      final showName = cleanMediaTitle(rawName);
      print('[PlayerScreen] Scraping initial subtitles for "$showName" (year: $searchYear, imdb: ${widget.detail?.id})...');

      final groups = await SubtitleService().fetchAllSubtitles(
        showName,
        imdbId: widget.detail?.id,
        season: _currentEpisode?.season,
        episode: _currentEpisode?.episode,
        year: searchYear,
      );
      print('[PlayerScreen] Scraped ${groups.length} subtitle language groups with ${groups.fold(0, (s, g) => s + g.variants.length)} total variants');
      if (mounted && groups.isNotEmpty) {
        setState(() => _subtitleGroups = groups);

        // Auto-load matching language subtitle for the new episode if subtitles were enabled
        if (_isSubtitleEnabled && _currentSubtitleVariant != null) {
          final previousLang = _currentSubtitleVariant!.language.toLowerCase();
          final matchingGroup = groups.firstWhere(
            (g) => g.language.toLowerCase() == previousLang,
            orElse: () => groups.firstWhere(
              (g) => g.language.toLowerCase().contains('english') || g.language.toLowerCase() == 'en',
              orElse: () => groups.first,
            ),
          );
          if (matchingGroup.variants.isNotEmpty) {
            _loadSubtitle(matchingGroup.variants.first);
          }
        }
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Error loading subtitles: $e');
    }
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

  void _selectEmbeddedSubtitle(PlayerEmbeddedSubtitle embedded) {
    setState(() {
      _selectedEmbeddedSubtitleIndex = embedded.index;
      _currentSubtitleVariant = SubtitleVariant(
        providerName: 'Embedded',
        language: embedded.language ?? 'Embedded',
        title: embedded.title,
        downloadUrl: '',
        format: embedded.codec ?? 'ass',
      );
      _isSubtitleEnabled = true;
      _currentSubtitlePath = null;
      _currentCues = [];
    });

    if (_controller != null) {
      _controller!.setExternalSubtitle('');
      _controller!.setSubtitleTracks([embedded.index]);
      _setSubtitleScale(_subtitleScale);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to embedded subtitle: ${embedded.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _disableSubtitles() {
    setState(() {
      _isSubtitleEnabled = false;
      _currentSubtitleVariant = null;
      _selectedEmbeddedSubtitleIndex = null;
      _currentSubtitlePath = null;
      _currentCues = [];
    });
    _controller?.setSubtitleTracks([-1]);
    _controller?.setExternalSubtitle('');
  }

  Future<void> _loadSubtitle(SubtitleVariant variant) async {
    _currentSubtitleVariant = variant;
    _selectedEmbeddedSubtitleIndex = null;
    _isSubtitleEnabled = true;
    _controller?.setSubtitleTracks([-1]);

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
        final cleanBase = _currentSubtitlePath!.replaceAll(
          RegExp(r'(_delayed.*|_synced.*)?\.(srt|vtt)$', caseSensitive: false),
          '',
        );
        final newPath = '${cleanBase}_delayed_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await File(newPath).writeAsString(content);
        _controller!.setExternalSubtitle(newPath);
        _setSubtitleScale(_subtitleScale);
      } else {
        final newPath = await _shiftSubtitleTime(_currentSubtitlePath!, _subtitleDelayMs);
        _controller!.setExternalSubtitle(newPath);
        _setSubtitleScale(_subtitleScale);
      }
    }
  }

  Future<void> _saveTextSyncedCues(List<SubCue> syncedCues, double offsetSec) async {
    _currentCues = syncedCues;
    _subtitleDelayMs = 0.0; // Reset live delay since timestamps are now permanently baked into cues
    if (_currentSubtitlePath != null && _controller != null) {
      final content = _currentSubFormat == SubFormat.vtt
          ? SubtitleParser.toVtt(syncedCues)
          : SubtitleParser.toSrt(syncedCues);
      final ext = _currentSubFormat == SubFormat.vtt ? 'vtt' : 'srt';
      final cleanBase = _currentSubtitlePath!.replaceAll(
        RegExp(r'(_delayed.*|_synced.*)?\.(srt|vtt)$', caseSensitive: false),
        '',
      );
      final newPath = '${cleanBase}_synced_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(newPath).writeAsString(content);
      _currentSubtitlePath = newPath;
      _controller!.setExternalSubtitle(newPath);
      _setSubtitleScale(_subtitleScale);

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

      if (_currentEpisode != null && widget.detail?.videos.isNotEmpty == true) {
        setState(() {
          _isLoading = false;
          _showSourcesPanel = true;
          _sourcesEpisode = _currentEpisode;
          _sourcesErrorMessage = 'Playback error: $errorMsg. Please select another source below.';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _statusMessage = 'Playback error: $errorMsg';
      });
    }
  }

  int _getControllerId(VideoPlayerController c) {
    try {
      // ignore: invalid_use_of_visible_for_testing_member
      return c.playerId;
    } catch (_) {
      return 0;
    }
  }

  void _applyVolume(double vol, {bool showHud = false}) {
    final clamped = ((vol * 100).round() / 100.0).clamp(0.0, PlayerVolumeControl.maxVolume);
    setState(() {
      _volume = clamped;
      _isMuted = clamped == 0;
      if (showHud) _showVolumeHud = true;
    });

    if (showHud) {
      _volumeHudTimer?.cancel();
      _volumeHudTimer = Timer(const Duration(milliseconds: 1300), () {
        if (mounted) setState(() => _showVolumeHud = false);
      });
    }

    if (_controller != null) {
      final id = _getControllerId(_controller!);
      if (id > 0) {
        try {
          VideoPlayerPlatform.instance.setVolume(id, clamped);
        } catch (e) {
          if (kDebugMode) print('[PlayerScreen] Platform setVolume error: $e');
          _controller!.setVolume(clamped.clamp(0.0, 1.0));
        }
      } else {
        _controller!.setVolume(clamped.clamp(0.0, 1.0));
      }
    }
  }

  void _toggleMute({bool showHud = false}) {
    if (_volume > 0 && !_isMuted) {
      _lastVolumeBeforeMute = _volume;
      setState(() {
        _isMuted = true;
        if (showHud) _showVolumeHud = true;
      });
      if (_controller != null) {
        final id = _getControllerId(_controller!);
        if (id > 0) {
          try {
            VideoPlayerPlatform.instance.setVolume(id, 0.0);
          } catch (_) {
            _controller!.setVolume(0.0);
          }
        } else {
          _controller!.setVolume(0.0);
        }
      }
    } else {
      final restore = _lastVolumeBeforeMute > 0 ? _lastVolumeBeforeMute : 1.0;
      setState(() {
        _volume = restore;
        _isMuted = false;
        if (showHud) _showVolumeHud = true;
      });
      if (_controller != null) {
        final id = _getControllerId(_controller!);
        if (id > 0) {
          try {
            VideoPlayerPlatform.instance.setVolume(id, restore);
          } catch (_) {
            _controller!.setVolume(restore.clamp(0.0, 1.0));
          }
        } else {
          _controller!.setVolume(restore.clamp(0.0, 1.0));
        }
      }
    }

    if (showHud) {
      _volumeHudTimer?.cancel();
      _volumeHudTimer = Timer(const Duration(milliseconds: 1300), () {
        if (mounted) setState(() => _showVolumeHud = false);
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
    _startHideControlsTimer();
  }

  void _seekRelative(Duration offset) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final cur = _controller!.value.position;
    final dur = _controller!.value.duration;
    final target = cur + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (dur > Duration.zero && target > dur ? dur : target);
    _controller!.seekTo(clamped);
    _startHideControlsTimer();
  }

  void _toggleEpisodesPanel() {
    setState(() {
      _showEpisodesPanel = !_showEpisodesPanel;
      if (_showEpisodesPanel) {
        _showSourcesPanel = false;
        _activeMenu = null;
        _showSubSyncBar = false;
        _showTextSyncOverlay = false;
        _showControls = true;
      }
    });
  }

  void _onEpisodeChosen(Video episode) {
    setState(() {
      _showEpisodesPanel = false;
      _showSourcesPanel = true;
      _sourcesEpisode = episode;
      _sourcesErrorMessage = null;
      _activeMenu = null;
      _showControls = true;
    });
  }

  void _onBackToEpisodes() {
    setState(() {
      _showSourcesPanel = false;
      _showEpisodesPanel = true;
      _sourcesErrorMessage = null;
    });
  }

  void _playNewSource(StreamSource newSource, Video episode) {
    setState(() {
      _showSourcesPanel = false;
      _showEpisodesPanel = false;
      _sourcesErrorMessage = null;
    });
    _switchStream(newSource, episode);
  }

  void _switchStream(StreamSource newSource, Video newEpisode) async {
    _progressSaveTimer?.cancel();
    _savePlaybackProgress();

    final prevVariant = _currentSubtitleVariant;
    final wasSubEnabled = _isSubtitleEnabled;

    setState(() {
      _currentSource = newSource;
      _currentEpisode = newEpisode;
      final showName = widget.detail?.name ?? widget.title;
      final epNum = newEpisode.episode ?? 1;
      final sNum = newEpisode.season ?? 1;
      _currentTitle = '$showName - S${sNum}E$epNum ${newEpisode.title}';
      _isLoading = true;
      _statusMessage = 'Buffering S$sNum:E$epNum - ${newEpisode.title.isNotEmpty ? newEpisode.title : "Episode $epNum"}...';
      _showEpisodesPanel = false;
      _showSourcesPanel = false;
      _activeMenu = null;
      _showSubSyncBar = false;
      _showTextSyncOverlay = false;
      _showSkipButton = false;
      _activeSkipSegment = null;
      _skipSegments = [];
      _subtitleGroups = [];
      _currentSubtitlePath = null;
      _currentCues = [];
      _currentSubtitleVariant = prevVariant;
      _isSubtitleEnabled = wasSubEnabled;
    });

    // Cleanup previous torrent engine if was P2P
    TorrentStreamService().cleanup();

    _controller?.removeListener(_onControllerError);
    _controller?.removeListener(_onPlaybackTick);
    await _controller?.dispose();
    _controller = null;

    _initStream();
  }

  void _fetchSkipSegments() async {
    try {
      final detail = widget.detail;
      final showName = widget.detail?.name ?? widget.title;
      final skipData = await SkipSegmentsService.instance.fetchSkipSegments(
        tmdbId: detail?.tmdbId,
        imdbId: (detail != null && detail.id.startsWith('tt')) ? detail.id : null,
        title: showName,
        year: int.tryParse(detail?.year ?? ''),
        type: detail?.type ?? (_currentEpisode != null ? 'tv' : 'movie'),
        season: _currentEpisode?.season,
        episode: _currentEpisode?.episode,
        durationMs: _controller?.value.duration.inMilliseconds,
      );

      if (skipData != null && mounted) {
        setState(() {
          _skipSegments = skipData.segments;
        });
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Error loading skip segments: $e');
    }
  }

  void _onPlaybackTick() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    // Auto-Resync master clock when recovering from buffer stalls
    final isBuffering = _controller!.value.isBuffering;
    if (_wasBuffering && !isBuffering && PlayerSettings.autoResyncOnStall.value) {
      try {
        if (PlayerSettings.hardwareAudioClock.value) {
          _controller?.setProperty('sync', 'audio');
        }
      } catch (e) {
        debugPrint('[PlayerScreen] Auto-resync error: $e');
      }
    }
    _wasBuffering = isBuffering;

    if (_skipSegments.isEmpty) return;

    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;

    MediaSkipSegment? matched;
    for (final seg in _skipSegments) {
      if (seg.contains(pos, dur)) {
        matched = seg;
        break;
      }
    }

    if (matched != null) {
      if (!_dismissedSegmentKeys.contains(matched.uniqueKey)) {
        if (_activeSkipSegment?.uniqueKey != matched.uniqueKey) {
          setState(() {
            _activeSkipSegment = matched;
            _showSkipButton = true;
          });
        }
      }
    } else {
      if (_activeSkipSegment != null) {
        setState(() {
          _activeSkipSegment = null;
          _showSkipButton = false;
        });
      }
    }
  }

  void _handleSkipSegment(MediaSkipSegment seg) {
    _dismissedSegmentKeys.add(seg.uniqueKey);
    final target = seg.endMs != null
        ? Duration(milliseconds: seg.endMs!)
        : (_controller?.value.duration ?? Duration.zero);

    _controller?.seekTo(target + const Duration(milliseconds: 300));

    setState(() {
      _showSkipButton = false;
      _activeSkipSegment = null;
    });
  }

  void _handleDismissSkipSegment(MediaSkipSegment seg) {
    _dismissedSegmentKeys.add(seg.uniqueKey);
    setState(() {
      _showSkipButton = false;
      _activeSkipSegment = null;
    });
  }

  void _savePlaybackProgress() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (widget.detail == null) return;

    final pos = _controller!.value.position.inSeconds;
    final dur = _controller!.value.duration.inSeconds;
    if (dur <= 0) return;

    ContinueWatchingService.saveProgress(
      detail: widget.detail!,
      episode: _currentEpisode,
      source: _currentSource,
      positionSeconds: pos,
      totalDurationSeconds: dur,
    );
  }

  @override
  void dispose() {
    _progressSaveTimer?.cancel();
    _volumeHudTimer?.cancel();
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
    _controller?.removeListener(_onPlaybackTick);
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
        body: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            // Never intercept key events when typing or searching in text inputs or overlay
            if (_showTextSyncOverlay) {
              return KeyEventResult.ignored;
            }
            final primaryFocus = FocusManager.instance.primaryFocus;
            if (primaryFocus != null && primaryFocus.context != null) {
              final focusedWidget = primaryFocus.context!.widget;
              if (focusedWidget is EditableText) {
                return KeyEventResult.ignored;
              }
            }

            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                  event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
                _applyVolume((_volume + 0.05).clamp(0.0, PlayerVolumeControl.maxVolume), showHud: true);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                  event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
                _applyVolume((_volume - 0.05).clamp(0.0, PlayerVolumeControl.maxVolume), showHud: true);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
                _toggleMute(showHud: true);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.keyK) {
                _togglePlayPause();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                  event.logicalKey == LogicalKeyboardKey.keyJ) {
                _seekRelative(const Duration(seconds: -10));
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                  event.logicalKey == LogicalKeyboardKey.keyL) {
                _seekRelative(const Duration(seconds: 10));
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
                WindowService.instance.toggleFullscreen();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final delta = pointerSignal.scrollDelta.dy < 0 ? 0.05 : -0.05;
                final next = (_volume + delta).clamp(0.0, PlayerVolumeControl.maxVolume);
                _applyVolume((next * 100).round() / 100.0, showHud: true);
              }
            },
            child: MouseRegion(
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

  Future<void> _handleDownloadMedia() async {
    final mediaId = widget.detail?.id ?? _currentTitle;
    final season = _currentEpisode?.season;
    final episode = _currentEpisode?.episode;

    final existing = DownloadService.instance.tasksNotifier.value.where((t) {
      if (t.mediaId == mediaId && t.season == season && t.episode == episode) {
        return true;
      }
      return false;
    }).firstOrNull;

    if (existing != null) {
      if (existing.status == DownloadStatus.downloading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download already in progress in background.')),
        );
        return;
      } else if (existing.status == DownloadStatus.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This media is already downloaded.')),
        );
        return;
      }
    }

    try {
      String? customDir;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        customDir = await DownloadPathHelper.pickDownloadsDirectory();
        if (customDir == null) {
          // User canceled folder selection
          return;
        }
      }

      await DownloadService.instance.startDownload(
        title: widget.detail?.name ?? _currentTitle,
        mediaId: mediaId,
        type: widget.detail?.type ?? (widget.detail?.videos.isNotEmpty == true ? 'series' : 'movie'),
        season: season,
        episode: episode,
        episodeTitle: _currentEpisode?.title,
        posterUrl: widget.detail?.poster,
        backdropUrl: widget.detail?.background,
        year: widget.detail?.year,
        source: _currentSource,
        customDownloadDir: customDir,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download started in background. Track progress in Downloads tab.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed to start: $e')),
        );
      }
    }
  }

  Widget _buildControlsOverlay() {
    final buffered = _controller?.value.buffered.isNotEmpty == true
        ? _controller!.value.buffered.last.end
        : null;

    final episodeTitle = _currentEpisode?.title;
    final episodeSubtitle = _currentEpisode != null
        ? 'S${_currentEpisode!.season ?? 1}:E${_currentEpisode!.episode ?? 1}${episodeTitle != null && episodeTitle.isNotEmpty ? " • $episodeTitle" : ""}'
        : widget.detail?.year;

    final isOfflineFile = _currentSource.name == 'Downloaded';

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
                child: ValueListenableBuilder<List<DownloadTask>>(
                  valueListenable: DownloadService.instance.tasksNotifier,
                  builder: (context, tasks, _) {
                    final mediaId = widget.detail?.id ?? _currentTitle;
                    final season = _currentEpisode?.season;
                    final episode = _currentEpisode?.episode;
                    final isDownloading = tasks.any((t) =>
                        t.mediaId == mediaId &&
                        t.season == season &&
                        t.episode == episode &&
                        t.status == DownloadStatus.downloading);

                    return PlayerTopBar(
                      title: widget.detail?.name ?? _currentTitle,
                      subtitle: episodeSubtitle,
                      quality: _currentSource.name,
                      onDownload: (_isLoading || isOfflineFile) ? null : _handleDownloadMedia,
                      isDownloading: isDownloading,
                      onToggleEpisodes: (!_isLoading && widget.detail?.videos.isNotEmpty == true)
                          ? _toggleEpisodesPanel
                          : null,
                      isEpisodesActive: _showEpisodesPanel || _showSourcesPanel,
                      onBack: () {
                        WindowService.instance.exitFullscreen();
                        Navigator.pop(context);
                      },
                    );
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
                              skipSegments: _skipSegments,
                              volume: _volume,
                              isMuted: _isMuted || _volume == 0,
                              playbackRate: _playbackRate,
                              isSubtitlesActive: _isSubtitleEnabled && _currentSubtitleVariant != null,
                              isSubSyncActive: _selectedEmbeddedSubtitleIndex == null && (_showSubSyncBar || _subtitleDelayMs != 0),
                              isAudioActive: _selectedAudioTrackIndex > 0,
                              isEpisodesActive: _showEpisodesPanel || _showSourcesPanel,
                              isFullscreen: isFs,
                              onToggleEpisodes: (widget.detail?.videos.isNotEmpty == true)
                                  ? _toggleEpisodesPanel
                                  : null,
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
                              onVolumeChanged: (vol) => _applyVolume(vol),
                              onToggleMute: () => _toggleMute(),
                              onToggleAspectMenu: () => _toggleMenu('aspect'),
                              onToggleSpeedMenu: () => _toggleMenu('speed'),
                              onToggleAudioMenu: () => _toggleMenu('audio'),
                              onToggleSubtitleMenu: () => _toggleMenu('subtitle'),
                              onToggleSubSync: () {
                                if (_selectedEmbeddedSubtitleIndex != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Subtitle sync is not supported for embedded subtitles. Please select an external subtitle.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                if (_currentSubtitlePath == null || _currentSubtitleVariant == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please load an external subtitle to use subtitle sync.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
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
                embeddedSubtitles: _embeddedSubtitles,
                selectedEmbeddedIndex: _selectedEmbeddedSubtitleIndex,
                selectedVariant: _currentSubtitleVariant,
                isSubtitleEnabled: _isSubtitleEnabled,
                movieTitle: widget.detail?.name ?? widget.title,
                imdbId: widget.detail?.id,
                season: _currentEpisode?.season,
                episode: _currentEpisode?.episode,
                year: widget.detail?.year != null ? int.tryParse(widget.detail!.year!) : null,
                delaySec: _subtitleDelayMs / 1000.0,
                onSelectVariant: (v) {
                  if (v != null) _loadSubtitle(v);
                },
                onSelectEmbedded: (emb) => _selectEmbeddedSubtitle(emb),
                onToggleOff: _disableSubtitles,
                onOpenSyncBar: () {
                  if (_selectedEmbeddedSubtitleIndex != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Subtitle sync is not supported for embedded subtitles.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _activeMenu = null;
                    _showSubSyncBar = true;
                  });
                },
                onOpenStyleBar: () {
                  setState(() => _activeMenu = 'style');
                },
                onOpenTextSync: () {
                  if (_selectedEmbeddedSubtitleIndex != null || _currentSubtitlePath == null || _currentCues.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Speech sync requires an external subtitle file.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
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
          if (_showSubSyncBar && !_isLoading && _selectedEmbeddedSubtitleIndex == null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              left: 0,
              right: 0,
              child: SubSyncBar(
                delaySec: _subtitleDelayMs / 1000.0,
                isTextSyncAvailable: _selectedEmbeddedSubtitleIndex == null && _currentSubtitlePath != null && _currentCues.isNotEmpty,
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

          // In-Player Episodes Side Panel
          if (_showEpisodesPanel && widget.detail?.videos.isNotEmpty == true && !_isLoading)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showEpisodesPanel = false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: GestureDetector(
                    onTap: () {},
                    child: PlayerEpisodesPanel(
                      videos: widget.detail!.videos,
                      currentEpisode: _currentEpisode,
                      onEpisodeSelected: _onEpisodeChosen,
                      onClose: () => setState(() => _showEpisodesPanel = false),
                    ),
                  ),
                ),
              ),
            ),

          // In-Player Sources Side Panel (Targeted Scraping & Error Recovery)
          if (_showSourcesPanel && _sourcesEpisode != null && !_isLoading)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showSourcesPanel = false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: GestureDetector(
                    onTap: () {},
                    child: PlayerSourcesPanel(
                      episode: _sourcesEpisode!,
                      detail: widget.detail,
                      currentAddonName: _currentSource.addonName,
                      errorMessage: _sourcesErrorMessage,
                      cachedSources: _cachedSourcesByEpisode['${_sourcesEpisode!.season ?? 1}:${_sourcesEpisode!.episode ?? 1}'],
                      onSourcesLoaded: (sources) {
                        _cachedSourcesByEpisode['${_sourcesEpisode!.season ?? 1}:${_sourcesEpisode!.episode ?? 1}'] = sources;
                      },
                      onPlaySource: _playNewSource,
                      onBackToEpisodes: _onBackToEpisodes,
                      onClose: () => setState(() => _showSourcesPanel = false),
                    ),
                  ),
                ),
              ),
            ),

          // Right Drawer Text Sync
          if (_showTextSyncOverlay && !_isLoading && _controller != null && _currentCues.isNotEmpty && _selectedEmbeddedSubtitleIndex == null)
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

          // Floating Skip Button (Skip Intro, Skip Recap, Skip Credits, Skip Preview)
          if (_showSkipButton && _activeSkipSegment != null && !_isLoading && !_showTextSyncOverlay && !_showEpisodesPanel && !_showSourcesPanel)
            Positioned(
              bottom: (_showControls || _activeMenu != null)
                  ? (MediaQuery.paddingOf(context).bottom +
                      (MediaQuery.sizeOf(context).width < 680 ? 108 : 128))
                  : (MediaQuery.paddingOf(context).bottom +
                      (MediaQuery.sizeOf(context).width < 680 ? 22 : 36)),
              right: MediaQuery.sizeOf(context).width < 680 ? 16 : 28,
              child: AnimatedOpacity(
                opacity: _showSkipButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: PlayerSkipButton(
                  segment: _activeSkipSegment!,
                  onSkip: () => _handleSkipSegment(_activeSkipSegment!),
                  onDismiss: () => _handleDismissSkipSegment(_activeSkipSegment!),
                ),
              ),
            ),

          // Center Heads-Up Volume Display (HUD)
          if (_showVolumeHud)
            Positioned.fill(
              child: IgnorePointer(
                child: _buildVolumeHud(),
              ),
            ),
        ],
      );
  }

  Widget _buildVolumeHud() {
    final effectiveVol = _isMuted ? 0.0 : _volume;
    final isBoosting = !_isMuted && _volume > 1.001;
    final pct = (effectiveVol * 100).round();
    final boostColor = _volume > 1.75
        ? const Color(0xFFFF3D00)
        : (_volume > 1.0 ? const Color(0xFFFF8A00) : Colors.white);

    IconData volIcon;
    if (_isMuted || _volume == 0) {
      volIcon = Icons.volume_off_rounded;
    } else if (_volume > 1.0) {
      volIcon = Icons.volume_up_rounded;
    } else if (_volume < 0.5) {
      volIcon = Icons.volume_down_rounded;
    } else {
      volIcon = Icons.volume_up_rounded;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isBoosting
                ? boostColor.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isBoosting ? boostColor.withValues(alpha: 0.28) : Colors.black54,
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  volIcon,
                  color: isBoosting ? boostColor : Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _isMuted ? 'Muted' : '$pct%',
                  style: TextStyle(
                    color: isBoosting ? boostColor : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (isBoosting) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: boostColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: boostColor.withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 13, color: boostColor),
                        const SizedBox(width: 2),
                        Text(
                          _volume > 1.75 ? 'MAX BOOST' : 'BOOST',
                          style: TextStyle(
                            color: boostColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 140,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.15)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (effectiveVol / PlayerVolumeControl.maxVolume).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isBoosting
                              ? LinearGradient(
                                  colors: [
                                    Colors.white,
                                    const Color(0xFFFF8A00),
                                    if (_volume > 1.75) const Color(0xFFFF3D00),
                                  ],
                                )
                              : null,
                          color: isBoosting ? null : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
