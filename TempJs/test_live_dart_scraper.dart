import 'dart:async';
import 'package:playtorrio/services/scraper/sites/downloadeverything.dart';

void main() async {
  print('=== 1. TESTING DART SCRAPER FOR MOVIE: THE AMATEUR (2025) ===\n');

  final scraper = DownloadEverythingScraper();

  final amateurStreams = <dynamic>[];
  await for (final s in scraper.scrapeStream(
    type: 'movie',
    title: 'The Amateur',
    year: 2025,
    imdbId: 'tt10362366',
  )) {
    amateurStreams.add(s);
    print('[+] DART STREAM FOUND: ${s.title} | URL: ${s.url}');
  }
  print('\nTotal streamable sources for The Amateur: ${amateurStreams.length}\n');

  print('=== 2. TESTING DART SCRAPER FOR MOVIE: OBSESSION (2026) ===\n');
  final obsessionStreams = <dynamic>[];
  await for (final s in scraper.scrapeStream(
    type: 'movie',
    title: 'Obsession',
    year: 2026,
    imdbId: 'tt37287335',
  )) {
    obsessionStreams.add(s);
    print('[+] DART STREAM FOUND: ${s.title} | URL: ${s.url}');
  }
  print('\nTotal streamable sources for Obsession: ${obsessionStreams.length}\n');

  print('=== 3. TESTING DART SCRAPER FOR TV: HOUSE OF THE DRAGON S01E01 ===\n');
  final tvStreams = <dynamic>[];
  await for (final s in scraper.scrapeStream(
    type: 'series',
    title: 'House of the Dragon',
    year: 2022,
    season: 1,
    episode: 1,
    imdbId: 'tt11198330',
  )) {
    tvStreams.add(s);
    print('[+] DART STREAM FOUND: ${s.title} | URL: ${s.url}');
  }
  print('\nTotal streamable sources for House of the Dragon: ${tvStreams.length}\n');
}
