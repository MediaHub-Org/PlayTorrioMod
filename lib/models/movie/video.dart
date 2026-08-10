class Video {
  final String id;
  final String title;
  final int? season;
  final int? episode;
  final String? released;
  final String? thumbnail;
  final String? overview;

  Video({
    required this.id,
    required this.title,
    this.season,
    this.episode,
    this.released,
    this.thumbnail,
    this.overview,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Episode',
      season: json['season'] as int?,
      episode: json['episode'] ?? json['number'] as int?,
      released: json['released']?.toString(),
      thumbnail: json['thumbnail']?.toString(),
      overview: json['overview']?.toString() ?? json['description']?.toString(),
    );
  }
}
