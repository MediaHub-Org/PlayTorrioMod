import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../playback_coordinator.dart';
import 'podcast_service.dart';

/// Plays one podcast episode at a time in the background, matching
/// [AudiobookPlayerController]'s shape but simpler -- a podcast episode is
/// a single audio stream, no chapters.
///
/// Built on `media_kit`/libmpv -- was on `video_player` (an audio-only
/// video player, a leftover workaround), the same issue
/// AudiobookPlayerController had before its own migration earlier this
/// session. That engine could fail to initialize a stream silently (a
/// caught exception, `debugPrint`-only, no UI-visible error) -- tapping an
/// episode looked like nothing happened at all, matching a report of
/// podcast playback just not starting.
class PodcastPlayerController extends ChangeNotifier {
  static final PodcastPlayerController instance = PodcastPlayerController._internal();
  PodcastPlayerController._internal();

  Player? _controller;
  final List<StreamSubscription> _subscriptions = [];
  PodcastResult? _podcast;
  PodcastEpisode? _episode;
  bool _isPlaying = false;
  bool _isLoading = false;

  VoidCallback? _onExpandRequested;

  PodcastResult? get podcast => _podcast;
  PodcastEpisode? get episode => _episode;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get hasEpisode => _episode != null;

  void setExpandCallback(VoidCallback callback) {
    _onExpandRequested = callback;
  }

  Future<void> play(PodcastResult podcast, PodcastEpisode episode) async {
    _podcast = podcast;
    _episode = episode;
    _isLoading = true;
    notifyListeners();

    PlaybackCoordinator.activate(
      'podcast:${podcast.id}:${episode.audioUrl}',
      () {
        _controller?.pause();
        _isPlaying = false;
        notifyListeners();
      },
      kind: 'podcast',
      title: episode.title,
      subtitle: podcast.name,
      coverUrl: podcast.artworkUrl,
      onTogglePlayPause: togglePlayPause,
      onExpand: _onExpandRequested,
      onSeek: seekTo,
      onFullStop: stop,
    );

    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    try {
      final player = Player();
      final media = Media(episode.audioUrl);

      _subscriptions.addAll([
        player.stream.playing.listen((playing) {
          if (playing != _isPlaying) {
            _isPlaying = playing;
            PlaybackCoordinator.setPlaying(playing);
            notifyListeners();
          }
        }),
        player.stream.position.listen((pos) {
          PlaybackCoordinator.setProgress(pos, player.state.duration);
        }),
        player.stream.duration.listen((_) => notifyListeners()),
        player.stream.error.listen((err) {
          _isLoading = false;
          _isPlaying = false;
          debugPrint('Podcast playback error: $err');
          notifyListeners();
        }),
      ]);

      // Open paused, then play -- open() defaults to play:true, which
      // would start playback a moment before the volume/other setup
      // below took effect (see MusicPlayerController for the same fix).
      await player.open(media, play: false);
      await player.setVolume(100.0);
      await player.play();

      _controller = player;
      _isLoading = false;
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isPlaying = false;
      debugPrint('Podcast playback error: $e');
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_controller == null) return;
    if (_isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _controller?.seek(position);
  }

  Future<void> stop() async {
    PlaybackCoordinator.release(
      _podcast != null && _episode != null ? 'podcast:${_podcast!.id}:${_episode!.audioUrl}' : '',
    );
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    await _controller?.dispose();
    _controller = null;
    _podcast = null;
    _episode = null;
    _isPlaying = false;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    _controller?.dispose();
    super.dispose();
  }
}
