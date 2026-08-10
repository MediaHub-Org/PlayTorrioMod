class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String artistId;
  final String album;
  final String albumId;
  final String coverUrl;
  final int durationSeconds;
  final bool explicit;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.artistId = '',
    required this.album,
    this.albumId = '',
    required this.coverUrl,
    required this.durationSeconds,
    this.explicit = false,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    final albumData = json['album'] is Map<String, dynamic> ? json['album'] as Map<String, dynamic> : {};
    final artistData = json['artist'] is Map<String, dynamic> ? json['artist'] as Map<String, dynamic> : {};

    String cover = albumData['cover_big']?.toString() ??
        albumData['cover_medium']?.toString() ??
        albumData['cover_small']?.toString() ??
        json['cover']?.toString() ??
        json['coverUrl']?.toString() ??
        '';

    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }

    return MusicTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Track',
      artist: artistData['name']?.toString() ?? json['artist']?.toString() ?? 'Unknown Artist',
      artistId: artistData['id']?.toString() ?? json['artistId']?.toString() ?? '',
      album: albumData['title']?.toString() ?? json['album']?.toString() ?? 'Single',
      albumId: albumData['id']?.toString() ?? json['albumId']?.toString() ?? '',
      coverUrl: cover,
      durationSeconds: int.tryParse(json['duration']?.toString() ?? json['durationSeconds']?.toString() ?? '') ?? 0,
      explicit: json['explicit'] == true || json['explicit'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'artistId': artistId,
    'album': album,
    'albumId': albumId,
    'coverUrl': coverUrl,
    'durationSeconds': durationSeconds,
    'explicit': explicit,
  };

  String get formattedDuration {
    if (durationSeconds <= 0) return '--:--';
    final mins = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class MusicArtist {
  final String id;
  final String name;
  final String pictureUrl;
  final int fanCount;

  const MusicArtist({
    required this.id,
    required this.name,
    required this.pictureUrl,
    this.fanCount = 0,
  });

  factory MusicArtist.fromJson(Map<String, dynamic> json) {
    String pic = json['picture_big']?.toString() ??
        json['picture_medium']?.toString() ??
        json['picture_small']?.toString() ??
        json['pictureUrl']?.toString() ??
        '';
    if (pic.startsWith('http://')) {
      pic = pic.replaceFirst('http://', 'https://');
    }
    return MusicArtist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Artist',
      pictureUrl: pic,
      fanCount: int.tryParse(json['nbFan']?.toString() ?? json['fanCount']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pictureUrl': pictureUrl,
    'fanCount': fanCount,
  };
}

class MusicAlbum {
  final String id;
  final String title;
  final String artistName;
  final String coverUrl;
  final int trackCount;

  const MusicAlbum({
    required this.id,
    required this.title,
    required this.artistName,
    required this.coverUrl,
    this.trackCount = 0,
  });

  factory MusicAlbum.fromJson(Map<String, dynamic> json) {
    final artistData = json['artist'] is Map<String, dynamic> ? json['artist'] as Map<String, dynamic> : {};
    String cover = json['cover_big']?.toString() ??
        json['cover_medium']?.toString() ??
        json['cover_small']?.toString() ??
        json['coverUrl']?.toString() ??
        '';
    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }
    return MusicAlbum(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Album',
      artistName: artistData['name']?.toString() ?? json['artistName']?.toString() ?? 'Unknown Artist',
      coverUrl: cover,
      trackCount: int.tryParse(json['nbTracks']?.toString() ?? json['trackCount']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artistName': artistName,
    'coverUrl': coverUrl,
    'trackCount': trackCount,
  };
}

class UserPlaylist {
  final String id;
  final String title;
  final String createdAt;
  final List<MusicTrack> tracks;

  UserPlaylist({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.tracks,
  });

  factory UserPlaylist.fromJson(Map<String, dynamic> json) {
    return UserPlaylist(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'My Playlist',
      createdAt: json['createdAt']?.toString() ?? '',
      tracks: (json['tracks'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((t) => MusicTrack.fromJson(t))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };
}
