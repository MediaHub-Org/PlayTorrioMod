import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final payload = {
    'mode': 'series',
    'title': 'House of the Dragon',
    'year': '2022',
    'tmdb_id': 94997,
    'imdb_id': 'tt11198330',
    'season': 1,
    'episode': 1,
  };

  print('Testing raw items for House of the Dragon S01E01...\n');

  final request = http.Request('POST', Uri.parse('https://slave.downloadeverythingfromeverywhere.com/'))
    ..headers.addAll({
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Origin': 'https://downloadeverythingfromeverywhere.com',
      'Referer': 'https://downloadeverythingfromeverywhere.com/',
      'Content-Type': 'application/json',
    })
    ..body = jsonEncode(payload);

  final client = http.Client();
  final res = await client.send(request);

  const lineSplitter = LineSplitter();
  final stream = res.stream.transform(utf8.decoder).transform(lineSplitter);

  final hitsBySite = <String, List<Map<String, dynamic>>>{};

  await for (final line in stream) {
    if (line.trim().isEmpty) continue;
    try {
      final p = jsonDecode(line.trim());
      if (p['t'] == 'hit' && p['links'] is List) {
        final site = p['site'].toString();
        hitsBySite[site] = (p['links'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
  }

  print('=== GROUPED RAW CANDIDATES FOR TV SHOW ===\n');
  for (final entry in hitsBySite.entries) {
    print('Site: [${entry.key}] (${entry.value.length} links)');
    for (final l in entry.value.take(3)) {
      print('  - URL: ${l['url']} | Name: ${l['name']} | Tags: ${l['tags']}');
    }
    print('');
  }
}
