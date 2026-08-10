import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/music/music_track.dart';

class OctaveSearchData {
  final List<MusicTrack> tracks;
  final List<MusicArtist> artists;
  final List<MusicAlbum> albums;

  const OctaveSearchData({
    required this.tracks,
    required this.artists,
    required this.albums,
  });
}

class OctaveArtistDetails {
  final MusicArtist artist;
  final List<MusicTrack> topTracks;
  final List<MusicAlbum> albums;
  final List<MusicArtist> relatedArtists;

  const OctaveArtistDetails({
    required this.artist,
    required this.topTracks,
    required this.albums,
    required this.relatedArtists,
  });
}

class OctavePlaylistDetails {
  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final List<MusicTrack> tracks;

  const OctavePlaylistDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.tracks,
  });
}

class OctaveMusicService {
  static final OctaveMusicService instance = OctaveMusicService._internal();
  OctaveMusicService._internal();

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  String? _cachedToken;
  DateTime? _tokenExpiry;

  /// Fetches a valid playback token from Octave Streaming API
  Future<String?> getPlaybackToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    try {
      final res = await http.get(
        Uri.parse('https://api.octavestreaming.com/api/playback-token'),
        headers: {
          'User-Agent': _ua,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = data['token']?.toString();
        final expiresIn = int.tryParse(data['expiresIn']?.toString() ?? '') ?? 43200;

        if (token != null && token.isNotEmpty) {
          _cachedToken = token;
          _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
          return token;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Searches tracks, artists, and albums
  Future<OctaveSearchData> searchFull(String query) async {
    if (query.trim().isEmpty) {
      return const OctaveSearchData(tracks: [], artists: [], albums: []);
    }

    try {
      final url = Uri.parse(
        'https://music.octavestreaming.com/api/search?q=${Uri.encodeComponent(query)}',
      );
      final res = await http.get(
        url,
        headers: {
          'User-Agent': _ua,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        
        final tracksList = (data['tracks'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((json) => MusicTrack.fromJson(json))
            .where((t) => t.id.isNotEmpty)
            .toList() ?? [];

        final artistsList = (data['artists'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((json) => MusicArtist.fromJson(json))
            .where((a) => a.id.isNotEmpty)
            .toList() ?? [];

        final albumsList = (data['albums'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((json) => MusicAlbum.fromJson(json))
            .where((a) => a.id.isNotEmpty)
            .toList() ?? [];

        return OctaveSearchData(
          tracks: tracksList,
          artists: artistsList,
          albums: albumsList,
        );
      }
    } catch (_) {}
    return const OctaveSearchData(tracks: [], artists: [], albums: []);
  }

  /// Searches tracks by query string
  Future<List<MusicTrack>> searchTracks(String query) async {
    final search = await searchFull(query);
    return search.tracks;
  }

  /// Resolves direct audio stream URL
  Future<String?> getAudioStreamUrl(String trackId, {String quality = 'lossless'}) async {
    final token = await getPlaybackToken();
    if (token == null || token.isEmpty) return null;
    return 'https://api.octavestreaming.com/audio/$quality?track=$trackId&token=$token';
  }

  /// Fetches artist details by artist ID
  Future<OctaveArtistDetails?> fetchArtistDetails(String artistId) async {
    try {
      final res = await http.get(
        Uri.parse('https://music.octavestreaming.com/api/artist/$artistId'),
        headers: {'User-Agent': _ua, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final artistObj = data['artist'] as Map<String, dynamic>?;
        if (artistObj == null) return null;

        final artist = MusicArtist.fromJson(artistObj);

        final topTracks = (data['top'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((json) => MusicTrack.fromJson(json))
            .toList() ?? [];

        final albums = (data['albums'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((json) => MusicAlbum.fromJson(json))
            .toList() ?? [];

        final related = (data['related'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((json) => MusicArtist.fromJson(json))
            .toList() ?? [];

        return OctaveArtistDetails(
          artist: artist,
          topTracks: topTracks,
          albums: albums,
          relatedArtists: related,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Fetches playlist details by playlist ID
  Future<OctavePlaylistDetails?> fetchPlaylistDetails(String playlistId) async {
    try {
      final res = await http.get(
        Uri.parse('https://music.octavestreaming.com/api/playlist/$playlistId'),
        headers: {'User-Agent': _ua, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final plObj = data['playlist'] as Map<String, dynamic>?;
        if (plObj == null) return null;

        final rawTracks = plObj['tracks'];
        List<dynamic> trackItems = [];
        if (rawTracks is Map<String, dynamic> && rawTracks['data'] is List) {
          trackItems = rawTracks['data'] as List;
        } else if (rawTracks is List) {
          trackItems = rawTracks;
        }

        final tracks = trackItems
            .whereType<Map<String, dynamic>>()
            .map((json) => MusicTrack.fromJson(json))
            .toList();

        return OctavePlaylistDetails(
          id: plObj['id']?.toString() ?? playlistId,
          title: plObj['title']?.toString() ?? 'Playlist',
          description: plObj['description']?.toString() ?? '',
          coverUrl: plObj['picture_big']?.toString() ?? plObj['picture_medium']?.toString() ?? '',
          tracks: tracks,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Fetches curated trending artists for Octave home view
  Future<List<MusicArtist>> fetchTrendingArtists() async {
    final search = await searchFull('The Weeknd Taylor Swift Drake Ariana Eilish');
    if (search.artists.isNotEmpty) {
      return search.artists.take(10).toList();
    }
    return [];
  }

  /// Fetches curated featured music sections for the Music page
  Future<Map<String, List<MusicTrack>>> fetchFeaturedSections() async {
    final results = <String, List<MusicTrack>>{};

    final queries = {
      '🔥 Top Playlists & Hits': 'The Weeknd',
      '🎧 Electronic & EDM': 'Daft Punk',
      '🌟 Pop Essentials': 'Dua Lipa',
      '🎬 Film & Anime Soundtracks': 'Hans Zimmer',
      '🎙️ Hip-Hop & Rap': 'Kendrick Lamar',
    };

    for (final entry in queries.entries) {
      final tracks = await searchTracks(entry.value);
      if (tracks.isNotEmpty) {
        results[entry.key] = tracks.take(12).toList();
      }
    }

    return results;
  }
}
