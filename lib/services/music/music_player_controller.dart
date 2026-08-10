import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/music/music_track.dart';
import 'music_service.dart';

class MusicPlayerController extends ChangeNotifier {
  static final MusicPlayerController instance = MusicPlayerController._internal();
  MusicPlayerController._internal();

  VideoPlayerController? _videoPlayerController;

  MusicTrack? _currentTrack;
  List<MusicTrack> _playlist = [];
  int _currentIndex = 0;

  bool _isLoading = false;
  bool _isPlaying = false;
  String? _errorMessage;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  String _currentQuality = 'lossless'; // 'lossless', '320', '128'

  // Getters
  MusicTrack? get currentTrack => _currentTrack;
  List<MusicTrack> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;
  String? get errorMessage => _errorMessage;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  String get currentQuality => _currentQuality;
  bool get hasTrack => _currentTrack != null;

  Future<void> playTrack(MusicTrack track, {List<MusicTrack>? playlistQueue, String quality = 'lossless'}) async {
    if (playlistQueue != null && playlistQueue.isNotEmpty) {
      _playlist = List<MusicTrack>.from(playlistQueue);
      _currentIndex = _playlist.indexWhere((t) => t.id == track.id);
      if (_currentIndex < 0) {
        _playlist.insert(0, track);
        _currentIndex = 0;
      }
    } else {
      if (!_playlist.any((t) => t.id == track.id)) {
        _playlist.add(track);
      }
      _currentIndex = _playlist.indexWhere((t) => t.id == track.id);
    }

    _currentQuality = quality;
    await _loadAndPlayTrack(track);
  }

  Future<void> _loadAndPlayTrack(MusicTrack track) async {
    _currentTrack = track;
    _isLoading = true;
    _errorMessage = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();

    if (_videoPlayerController != null) {
      _videoPlayerController!.removeListener(_onPlayerStateChanged);
      await _videoPlayerController!.dispose();
      _videoPlayerController = null;
    }

    try {
      final audioUrl = await OctaveMusicService.instance.getAudioStreamUrl(
        track.id,
        quality: _currentQuality,
      );

      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception('Failed to resolve audio stream URL from Octave API');
      }

      final uri = Uri.parse(audioUrl);
      final controller = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          'Referer': 'https://music.octavestreaming.com/',
        },
      );

      await controller.initialize();
      controller.setVolume(_volume);
      controller.addListener(_onPlayerStateChanged);

      _videoPlayerController = controller;
      _duration = controller.value.duration;
      _isLoading = false;
      _isPlaying = true;
      notifyListeners();

      await controller.play();
    } catch (e) {
      _isLoading = false;
      _isPlaying = false;
      _errorMessage = 'Playback Error: $e';
      notifyListeners();
    }
  }

  void _onPlayerStateChanged() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;

    final val = _videoPlayerController!.value;
    _position = val.position;
    _duration = val.duration;
    _isPlaying = val.isPlaying;

    if (_duration > Duration.zero && _position >= _duration - const Duration(milliseconds: 500)) {
      nextTrack();
    } else {
      notifyListeners();
    }
  }

  void togglePlayPause() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;

    if (_videoPlayerController!.value.isPlaying) {
      _videoPlayerController!.pause();
      _isPlaying = false;
    } else {
      _videoPlayerController!.play();
      _isPlaying = true;
    }
    notifyListeners();
  }

  void seekTo(Duration pos) {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
    _videoPlayerController!.seekTo(pos);
    _position = pos;
    notifyListeners();
  }

  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    _videoPlayerController?.setVolume(_volume);
    notifyListeners();
  }

  void setQuality(String quality) {
    if (_currentQuality == quality || _currentTrack == null) return;
    final currentPos = _position;
    _currentQuality = quality;
    _loadAndPlayTrack(_currentTrack!).then((_) {
      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        _videoPlayerController!.seekTo(currentPos);
      }
    });
  }

  void nextTrack() {
    if (_playlist.isEmpty) return;
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      _loadAndPlayTrack(_playlist[_currentIndex]);
    } else {
      _currentIndex = 0;
      _loadAndPlayTrack(_playlist[_currentIndex]);
    }
  }

  void previousTrack() {
    if (_playlist.isEmpty) return;
    if (_position.inSeconds > 4) {
      seekTo(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      _loadAndPlayTrack(_playlist[_currentIndex]);
    } else {
      _currentIndex = _playlist.length - 1;
      _loadAndPlayTrack(_playlist[_currentIndex]);
    }
  }

  void closePlayer() {
    _videoPlayerController?.removeListener(_onPlayerStateChanged);
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    _currentTrack = null;
    _isPlaying = false;
    notifyListeners();
  }
}
