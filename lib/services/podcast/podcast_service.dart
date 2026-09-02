import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert';

/// A podcast search result from the iTunes Search API (free, no key needed).
class PodcastResult {
  final String id;
  final String name;
  final String artistName;
  final String artworkUrl;
  final String feedUrl;

  const PodcastResult({
    required this.id,
    required this.name,
    required this.artistName,
    required this.artworkUrl,
    required this.feedUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'artistName': artistName,
        'artworkUrl': artworkUrl,
        'feedUrl': feedUrl,
      };

  factory PodcastResult.fromJson(Map<String, dynamic> json) => PodcastResult(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        artistName: json['artistName']?.toString() ?? '',
        artworkUrl: json['artworkUrl']?.toString() ?? '',
        feedUrl: json['feedUrl']?.toString() ?? '',
      );
}

/// A single episode parsed out of a podcast's RSS feed.
class PodcastEpisode {
  final String title;
  final String description;
  final String audioUrl;
  final String pubDate;
  final String duration;

  const PodcastEpisode({
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.pubDate,
    required this.duration,
  });
}

/// Podcasts via the iTunes Search API for discovery, then reads each
/// podcast's own RSS feed directly for episodes -- the standard way every
/// podcast app sources episode audio, no proprietary catalog needed.
class PodcastService {
  static const _searchBase = 'https://itunes.apple.com/search';
  static const _lookupBase = 'https://itunes.apple.com/lookup';
  static const _topPodcastsBase = 'https://itunes.apple.com/us/rss/toppodcasts';
  static final _client = http.Client();

  List<PodcastResult> _mapLookupResults(List<dynamic> results) {
    return results
        .map((e) => e as Map<String, dynamic>)
        .where((e) => (e['feedUrl'] as String?)?.isNotEmpty == true)
        .map((e) => PodcastResult(
              id: '${e['collectionId']}',
              name: e['collectionName'] as String? ?? '',
              artistName: e['artistName'] as String? ?? '',
              artworkUrl: e['artworkUrl600'] as String? ?? e['artworkUrl100'] as String? ?? '',
              feedUrl: e['feedUrl'] as String,
            ))
        .toList();
  }

  Future<List<PodcastResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = Uri.parse(_searchBase).replace(queryParameters: {
        'term': query,
        'media': 'podcast',
        'entity': 'podcast',
        'limit': '25',
      });
      final response = await _client.get(url);
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _mapLookupResults(json['results'] as List<dynamic>? ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Apple's public "Top Podcasts" chart -- no key needed, same as [search].
  /// The chart feed itself only gives id/name/artist/art, not a usable
  /// [PodcastResult.feedUrl], so the ids get a second batched `/lookup` call
  /// (same shape [search] already trusts) to fill that in -- one extra
  /// request for up to 200 ids, not one request per podcast.
  Future<List<PodcastResult>> fetchTopPodcasts({int limit = 20}) async {
    try {
      final chartUrl = Uri.parse('$_topPodcastsBase/limit=$limit/json');
      final chartResponse = await _client.get(chartUrl);
      if (chartResponse.statusCode != 200) return [];

      final chartJson = jsonDecode(chartResponse.body) as Map<String, dynamic>;
      final entries = (chartJson['feed'] as Map<String, dynamic>?)?['entry'] as List<dynamic>? ?? [];
      final ids = entries
          .map((e) => e as Map<String, dynamic>)
          .map((e) => ((e['id'] as Map<String, dynamic>?)?['attributes'] as Map<String, dynamic>?)?['im:id'] as String?)
          .whereType<String>()
          .toList();
      if (ids.isEmpty) return [];

      final lookupUrl = Uri.parse(_lookupBase).replace(queryParameters: {
        'id': ids.join(','),
        'entity': 'podcast',
      });
      final lookupResponse = await _client.get(lookupUrl);
      if (lookupResponse.statusCode != 200) return [];

      final lookupJson = jsonDecode(lookupResponse.body) as Map<String, dynamic>;
      final byId = {
        for (final r in _mapLookupResults(lookupJson['results'] as List<dynamic>? ?? [])) r.id: r,
      };
      // Preserve chart order -- the lookup response isn't guaranteed to.
      return ids.map((id) => byId[id]).whereType<PodcastResult>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PodcastEpisode>> fetchEpisodes(String feedUrl) async {
    try {
      final response = await _client.get(Uri.parse(feedUrl));
      if (response.statusCode != 200) return [];

      final document = XmlDocument.parse(response.body);
      final episodes = <PodcastEpisode>[];
      for (final item in document.findAllElements('item')) {
        final enclosure = item.findElements('enclosure').firstOrNull;
        final audioUrl = enclosure?.getAttribute('url') ?? '';
        if (audioUrl.isEmpty) continue;

        episodes.add(PodcastEpisode(
          title: item.findElements('title').firstOrNull?.innerText.trim() ?? 'Untitled episode',
          description: item.findElements('description').firstOrNull?.innerText.trim() ?? '',
          audioUrl: audioUrl,
          pubDate: item.findElements('pubDate').firstOrNull?.innerText.trim() ?? '',
          duration: item
                  .findElements('duration', namespaceUri: 'http://www.itunes.com/dtds/podcast-1.0.dtd')
                  .firstOrNull
                  ?.innerText
                  .trim() ??
              '',
        ));
      }
      return episodes;
    } catch (_) {
      return [];
    }
  }
}
