import 'package:playtorrio/services/scraper/sites/downloadeverything.dart';

void main() async {
  print('=== TESTING DART SCRAPER FOR THE BOYS S01E01 ===\n');

  final scraper = DownloadEverythingScraper();
  final streams = <dynamic>[];

  await for (final s in scraper.scrapeStream(
    type: 'series',
    title: 'The Boys',
    year: 2019,
    season: 1,
    episode: 1,
    imdbId: 'tt1190634',
  )) {
    streams.add(s);
    print('[+] DART STREAM: ${s.title}\n    URL: ${s.url}\n');
  }

  print('Total The Boys streams found: ${streams.length}');
}
