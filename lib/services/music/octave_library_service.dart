import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/music/music_track.dart';

class OctaveLibraryService extends ChangeNotifier {
  static final OctaveLibraryService instance = OctaveLibraryService._internal();
  OctaveLibraryService._internal();

  static const String _likedTracksKey = 'octave_liked_tracks_v1';
  static const String _userPlaylistsKey = 'octave_user_playlists_v1';

  final List<MusicTrack> _likedTracks = [];
  final List<UserPlaylist> _userPlaylists = [];
  bool _initialized = false;

  List<MusicTrack> get likedTracks => List.unmodifiable(_likedTracks);
  List<UserPlaylist> get userPlaylists => List.unmodifiable(_userPlaylists);
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Liked Tracks
      final likedString = prefs.getString(_likedTracksKey);
      if (likedString != null && likedString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(likedString);
        _likedTracks.clear();
        for (final item in jsonList) {
          if (item is Map<String, dynamic>) {
            _likedTracks.add(MusicTrack.fromJson(item));
          }
        }
      }

      // Load User Playlists
      final playlistsString = prefs.getString(_userPlaylistsKey);
      if (playlistsString != null && playlistsString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(playlistsString);
        _userPlaylists.clear();
        for (final item in jsonList) {
          if (item is Map<String, dynamic>) {
            _userPlaylists.add(UserPlaylist.fromJson(item));
          }
        }
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing OctaveLibraryService: $e');
    }
  }

  bool isTrackLiked(String trackId) {
    return _likedTracks.any((t) => t.id == trackId);
  }

  Future<void> toggleLikeTrack(MusicTrack track) async {
    final index = _likedTracks.indexWhere((t) => t.id == track.id);
    if (index >= 0) {
      _likedTracks.removeAt(index);
    } else {
      _likedTracks.insert(0, track);
    }
    await _saveLikedTracks();
    notifyListeners();
  }

  Future<UserPlaylist> createPlaylist(String title) async {
    final newPlaylist = UserPlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'My Playlist' : title.trim(),
      createdAt: DateTime.now().toIso8601String(),
      tracks: [],
    );
    _userPlaylists.insert(0, newPlaylist);
    await _saveUserPlaylists();
    notifyListeners();
    return newPlaylist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    _userPlaylists.removeWhere((p) => p.id == playlistId);
    await _saveUserPlaylists();
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, MusicTrack track) async {
    final index = _userPlaylists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = _userPlaylists[index];
      if (!pl.tracks.any((t) => t.id == track.id)) {
        pl.tracks.add(track);
        await _saveUserPlaylists();
        notifyListeners();
      }
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final index = _userPlaylists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      _userPlaylists[index].tracks.removeWhere((t) => t.id == trackId);
      await _saveUserPlaylists();
      notifyListeners();
    }
  }

  Future<void> _saveLikedTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _likedTracks.map((t) => t.toJson()).toList();
      await prefs.setString(_likedTracksKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving liked tracks: $e');
    }
  }

  Future<void> _saveUserPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _userPlaylists.map((p) => p.toJson()).toList();
      await prefs.setString(_userPlaylistsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving user playlists: $e');
    }
  }
}
