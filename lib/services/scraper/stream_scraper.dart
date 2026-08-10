import 'dart:async';
import '../../models/stream/stream_model.dart';

abstract class StreamScraper {
  String get name;
  
  Future<List<StreamSource>> scrape({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  });
}

class ScraperManager {
  static final ScraperManager instance = ScraperManager._internal();
  ScraperManager._internal();

  final List<StreamScraper> _scrapers = [];
  bool get hasScrapers => _scrapers.isNotEmpty;

  void registerScraper(StreamScraper scraper) {
    if (!_scrapers.any((s) => s.runtimeType == scraper.runtimeType)) {
      _scrapers.add(scraper);
    }
  }

  Stream<StreamSource> scrapeAll({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) {
    final controller = StreamController<StreamSource>();

    if (_scrapers.isEmpty) {
      controller.close();
      return controller.stream;
    }

    print('[ScraperManager] Scraping across ${_scrapers.length} active scrapers for "$title" (type: $type, imdbId: $imdbId)...');

    int pending = _scrapers.length;
    final seenHashes = <String>{};

    for (final scraper in _scrapers) {
      scraper.scrape(
        type: type,
        title: title,
        year: year,
        season: season,
        episode: episode,
        imdbId: imdbId,
      ).then((sources) {
        if (!controller.isClosed) {
          for (final source in sources) {
            if (source.infoHash != null) {
              final hashLower = source.infoHash!.toLowerCase();
              if (seenHashes.contains(hashLower)) continue;
              seenHashes.add(hashLower);
            }
            controller.add(source);
          }
        }
      }).catchError((e) {
        print('Scraper error (${scraper.name}): $e');
      }).whenComplete(() {
        pending--;
        if (pending == 0 && !controller.isClosed) {
          controller.close();
        }
      });
    }

    return controller.stream;
  }
}
