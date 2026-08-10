class Audiobook {
  final String uuid;
  final String audioBookId;
  final String dynamicSlugId;
  final String title;
  final String coverImage;
  final String source;
  final String pageUrl;

  Audiobook({
    required this.uuid,
    required this.audioBookId,
    required this.dynamicSlugId,
    required this.title,
    required this.coverImage,
    required this.source,
    required this.pageUrl,
  });

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'audioBookId': audioBookId,
        'dynamicSlugId': dynamicSlugId,
        'title': title,
        'coverImage': coverImage,
        'source': source,
        'pageUrl': pageUrl,
      };

  factory Audiobook.fromJson(Map<String, dynamic> json) => Audiobook(
        uuid: json['uuid'] ?? '',
        audioBookId: json['audioBookId'] ?? '',
        dynamicSlugId: json['dynamicSlugId'] ?? '',
        title: json['title'] ?? '',
        coverImage: json['coverImage'] ?? '',
        source: json['source'] ?? '',
        pageUrl: json['pageUrl'] ?? '',
      );
}

class AudiobookChapter {
  final String title;
  final String url;
  final Map<String, String>? httpHeaders;
  final bool isTorrent;
  final int? torrentFileIndex;

  AudiobookChapter({
    required this.title,
    required this.url,
    this.httpHeaders,
    this.isTorrent = false,
    this.torrentFileIndex,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'httpHeaders': httpHeaders,
        'isTorrent': isTorrent,
        'torrentFileIndex': torrentFileIndex,
      };

  factory AudiobookChapter.fromJson(Map<String, dynamic> json) => AudiobookChapter(
        title: json['title'] ?? '',
        url: json['url'] ?? '',
        httpHeaders: (json['httpHeaders'] as Map?)?.cast<String, String>(),
        isTorrent: json['isTorrent'] ?? false,
        torrentFileIndex: json['torrentFileIndex'],
      );
}
