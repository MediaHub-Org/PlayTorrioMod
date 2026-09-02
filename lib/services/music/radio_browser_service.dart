import 'dart:convert';
import 'package:http/http.dart' as http;

/// A live radio station from the Radio Browser API (radio-browser.info) --
/// a free, keyless, community-run directory of real station stream URLs.
class RadioStation {
  final String id;
  final String name;
  final String streamUrl;
  final String favicon;
  final String country;
  final String tags;
  final String codec;
  final int bitrateKbps;

  const RadioStation({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.favicon,
    required this.country,
    required this.tags,
    required this.codec,
    required this.bitrateKbps,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      id: json['stationuuid']?.toString() ?? '',
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString().trim()
          : 'Unknown Station',
      streamUrl: (json['url_resolved']?.toString().isNotEmpty ?? false)
          ? json['url_resolved'].toString()
          : json['url']?.toString() ?? '',
      favicon: json['favicon']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      tags: json['tags']?.toString() ?? '',
      codec: json['codec']?.toString() ?? '',
      bitrateKbps: int.tryParse(json['bitrate']?.toString() ?? '') ?? 0,
    );
  }

  /// Local persistence roundtrip (RadioLibraryService's liked list) -- this
  /// class's own field names, distinct from [fromJson]'s radio-browser.info
  /// API shape.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'streamUrl': streamUrl,
    'favicon': favicon,
    'country': country,
    'tags': tags,
    'codec': codec,
    'bitrateKbps': bitrateKbps,
  };

  factory RadioStation.fromLocalJson(Map<String, dynamic> json) {
    return RadioStation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Station',
      streamUrl: json['streamUrl']?.toString() ?? '',
      favicon: json['favicon']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      tags: json['tags']?.toString() ?? '',
      codec: json['codec']?.toString() ?? '',
      bitrateKbps: int.tryParse(json['bitrateKbps']?.toString() ?? '') ?? 0,
    );
  }
}

/// Fetches real stations from the Radio Browser API. No API key; a handful
/// of independently-run mirrors serve the same data, so a mirror going down
/// doesn't take Radio down with it.
class RadioBrowserService {
  RadioBrowserService._();

  // ponytail: fixed mirror list, not the documented DNS-SRV discovery --
  // three mirrors covers the realistic "one host is down" case. Switch to
  // SRV lookup if all three start going stale.
  static const _mirrors = [
    'https://de1.api.radio-browser.info',
    'https://fr1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
  ];

  static const _headers = {'User-Agent': 'PlayTorrioMod/1.0'};

  static Future<List<RadioStation>> _get(String path) async {
    for (final mirror in _mirrors) {
      try {
        final response = await http
            .get(Uri.parse('$mirror$path'), headers: _headers)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body) as List<dynamic>;
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(RadioStation.fromJson)
            .where((s) => s.streamUrl.isNotEmpty)
            .toList();
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  /// Popular stations overall, no genre filter.
  static Future<List<RadioStation>> topStations({int limit = 24}) {
    return _get('/json/stations/topclick/$limit?hidebroken=true');
  }

  /// Popular stations tagged with [genre] (e.g. "pop", "jazz", "lofi").
  static Future<List<RadioStation>> byGenre(String genre, {int limit = 24}) {
    final encoded = Uri.encodeComponent(genre);
    return _get(
      '/json/stations/search?tag=$encoded&limit=$limit&hidebroken=true&order=clickcount&reverse=true',
    );
  }

  /// Stations whose name matches [query] (a real text search, unlike
  /// [byGenre]'s exact-tag match).
  static Future<List<RadioStation>> search(String query, {int limit = 30}) {
    final encoded = Uri.encodeComponent(query);
    return _get(
      '/json/stations/search?name=$encoded&limit=$limit&hidebroken=true&order=clickcount&reverse=true',
    );
  }
}
