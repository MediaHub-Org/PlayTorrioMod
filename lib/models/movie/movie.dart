class Movie {
  final String id;
  final String name;
  final String? poster;
  final String? year;
  final String type;
  final String addonBaseUrl;

  Movie({
    required this.id,
    required this.name,
    this.poster,
    this.year,
    required this.type,
    required this.addonBaseUrl,
  });

  factory Movie.fromJson(Map<String, dynamic> json, String addonBaseUrl) {
    return Movie(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      poster: json['poster']?.toString(),
      year: json['releaseInfo']?.toString() ?? json['year']?.toString(),
      type: json['type']?.toString() ?? 'movie',
      addonBaseUrl: addonBaseUrl,
    );
  }
}
