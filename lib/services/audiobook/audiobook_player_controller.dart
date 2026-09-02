import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../models/audiobook/audiobook_model.dart';
import '../playback_coordinator.dart';
import '../stream/torrent_stream_service.dart';

/// A singleton controller that plays audiobooks in the **background**, so the
/// universal play bar appears instead of a fullscreen player.
///
/// Starting an audiobook from a detail page uses this controller (bottom bar
/// shows). Tapping the bottom bar opens the fullscreen player via
/// [setExpandCallback].
///
/// Built on `media_kit`/libmpv -- the same engine [MusicPlayerController]
/// and the fullscreen `AudiobookPlayerScreen` already use. This controller
/// used to run on `video_player` (an audio-only video player, a leftover
/// workaround), the one place in audiobook playback still on the old
/// engine while everything else had already moved.
class AudiobookPlayerController extends ChangeNotifier {
  static final AudiobookPlayerController instance =
      AudiobookPlayerController._internal();
  AudiobookPlayerController._internal();

  Player? _controller;
  final List<StreamSubscription> _subscriptions = [];
  Duration _position = Duration.zero;
  Audiobook? _audiobook;
  List<AudiobookChapter> _chapters = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = false;

  VoidCallback? _onExpandRequested;

  Audiobook? get audiobook => _audiobook;
  List<AudiobookChapter> get chapters => _chapters;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get hasAudiobook => _audiobook != null;

  void setExpandCallback(VoidCallback callback) {
    _onExpandRequested = callback;
  }

  Future<void> play(
    Audiobook audiobook,
    List<AudiobookChapter> chapters, {
    int chapterIndex = 0,
    Duration? initialPosition,
  }) async {
    _audiobook = audiobook;
    _chapters = chapters;
    _currentIndex = chapterIndex;

    PlaybackCoordinator.activate(
      'audiobook:${audiobook.uuid}:$chapterIndex',
      () {
        _controller?.pause();
        _isPlaying = false;
        notifyListeners();
      },
      kind: 'audiobook',
      title: audiobook.title,
      subtitle: chapters.isNotEmpty ? chapters[chapterIndex].title : '',
      coverUrl: audiobook.coverImage,
      onTogglePlayPause: togglePlayPause,
      onExpand: _onExpandRequested,
      onSeek: seekTo,
      onFullStop: stop,
      onNext: chapters.length > 1 ? nextChapter : null,
      onPrevious: chapters.length > 1 ? previousChapter : null,
    );

    await _loadChapter(chapterIndex, initialPosition: initialPosition);
  }

  Future<void> _loadChapter(int index, {Duration? initialPosition}) async {
    if (index < 0 || index >= _chapters.length) return;
    _currentIndex = index;
    _isLoading = true;
    notifyListeners();

    // Clean up previous controller
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    final chapter = _chapters[index];
    try {
      String? streamUrl;
      if (chapter.isTorrent) {
        streamUrl = await TorrentStreamService().streamTorrent(
          chapter.url,
          fileIdx: chapter.torrentFileIndex,
        );
      } else {
        streamUrl = chapter.url;
      }
      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('Audio stream URL could not be resolved.');
      }

      final sanitized = streamUrl.contains('::')
          ? streamUrl.replaceAll('::', '%3A%3A')
          : streamUrl;
      final headers = <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
      if (chapter.httpHeaders != null) headers.addAll(chapter.httpHeaders!);

      final player = Player();
      final media = Media(sanitized, httpHeaders: headers);

      _subscriptions.addAll([
        player.stream.playing.listen((playing) {
          if (playing != _isPlaying) {
            _isPlaying = playing;
            PlaybackCoordinator.setPlaying(playing);
            notifyListeners();
          }
        }),
        player.stream.position.listen((pos) {
          _position = pos;
          PlaybackCoordinator.setProgress(_position, player.state.duration);
        }),
        player.stream.duration.listen((_) => notifyListeners()),
        player.stream.error.listen((err) {
          _isLoading = false;
          _isPlaying = false;
          debugPrint('Audiobook background playback error: $err');
          notifyListeners();
        }),
      ]);

      // Open paused, then seek, then play -- open() defaults to play:true,
      // which would start the chapter from 0:00 for a moment before a
      // resume seek landed (see MusicPlayerController for the same fix).
      await player.open(media, play: false);
      await player.setVolume(100.0);
      if (initialPosition != null && initialPosition > Duration.zero) {
        await player.seek(initialPosition);
      }
      await player.play();

      _controller = player;
      _isLoading = false;
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isPlaying = false;
      debugPrint('Audiobook background playback error: $e');
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

  /// Advances to the next chapter. What the media session's skip-forward
  /// button maps to — an audiobook's chapter list is its queue.
  Future<void> nextChapter() async {
    if (_currentIndex >= _chapters.length - 1) return;
    await _loadChapter(_currentIndex + 1);
  }

  /// Restarts the current chapter, or steps back a chapter when already near
  /// its start — the convention every media app's skip-back button follows.
  Future<void> previousChapter() async {
    final position = _position;
    if (position.inSeconds > 3 || _currentIndex == 0) {
      await seekTo(Duration.zero);
      return;
    }
    await _loadChapter(_currentIndex - 1);
  }

  Future<void> stop() async {
    PlaybackCoordinator.release(
      _audiobook != null ? 'audiobook:${_audiobook!.uuid}:$_currentIndex' : '',
    );
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    await _controller?.dispose();
    _controller = null;
    _audiobook = null;
    _chapters = [];
    _isPlaying = false;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _controller?.dispose();
    super.dispose();
  }
}
