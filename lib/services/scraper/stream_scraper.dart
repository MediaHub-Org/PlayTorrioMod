import 'dart:async';
import '../../models/stream/stream_model.dart';

abstract class StreamScraper {
  String get name;

  /// Yields sources progressively one-by-one as they are resolved.
  Stream<StreamSource> scrapeStream({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) async* {
    final list = await scrape(
      type: type,
      title: title,
      year: year,
      season: season,
      episode: episode,
      imdbId: imdbId,
    );
    for (final s in list) {
      yield s;
    }
  }

  /// Bulk scrape fallback.
  Future<List<StreamSource>> scrape({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) async {
    return [];
  }
}

class ScraperManager {
  ScraperManager._internal();
  static final ScraperManager instance = ScraperManager._internal();

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

    print('[ScraperManager] Scraping across ${_scrapers.length} active scrapers (${_scrapers.map((s) => s.runtimeType).join(", ")}) for "$title"...');

    int pending = _scrapers.length;
    final seenHashes = <String>{};

    for (final scraper in _scrapers) {
      scraper
          .scrapeStream(
        type: type,
        title: title,
        year: year,
        season: season,
        episode: episode,
        imdbId: imdbId,
      )
          .listen(
        (source) {
          if (!controller.isClosed) {
            if (source.infoHash != null) {
              final hashLower = source.infoHash!.toLowerCase();
              if (seenHashes.contains(hashLower)) return;
              seenHashes.add(hashLower);
            }
            controller.add(source);
          }
        },
        onError: (_) {},
        onDone: () {
          pending--;
          if (pending == 0 && !controller.isClosed) {
            controller.close();
          }
        },
      );
    }

    return controller.stream;
  }
}
