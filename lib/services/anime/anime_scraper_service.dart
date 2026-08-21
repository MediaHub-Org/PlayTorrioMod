import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/anime/anime_media.dart';
import '../../models/movie/movie_detail.dart';
import '../../models/movie/video.dart';
import '../../models/stream/stream_model.dart';
import 'extractors/anikoto_resolver.dart';
import 'extractors/allanime_extractor.dart';
import 'extractors/miruro_extractor.dart';
import 'extractors/watchhentai_extractor.dart';
import 'extractors/hentaini_extractor.dart';

class AnimeScraperService {
  static final AnimeScraperService instance = AnimeScraperService._internal();
  AnimeScraperService._internal();

  final AnikotoResolver _anikoto = AnikotoResolver.instance;
  final AllAnimeExtractor _allAnime = AllAnimeExtractor();
  final MiruroExtractor _miruro = MiruroExtractor();
  final WatchHentaiExtractor _watchHentai = WatchHentaiExtractor();
  final HentainiExtractor _hentaini = HentainiExtractor();

  /// Scrape all stream sources for an Anime and Episode across all native extractors concurrently.
  Stream<StreamSource> scrapeStreamsStream({
    required AnimeMedia anime,
    required int episodeNumber,
    String? categoryFilter, // 'sub', 'dub', or null for both
  }) {
    final controller = StreamController<StreamSource>();
    final seenUrls = <String>{};

    final titleCandidates = [
      anime.titleEnglish,
      anime.titleRomaji,
      anime.titleUserPreferred,
      anime.titleNative,
    ].where((t) => t.trim().isNotEmpty).toList();

    () async {
      final tasks = <Future>[];

      // 1. Anikoto -> MegaPlay (HD-1) & VidWish (HD-2)
      tasks.add(() async {
        try {
          final series = await _anikoto.resolveAnikoto(
            anilistId: anime.id,
            titleCandidates: titleCandidates,
            expectedEpisodes: anime.totalEpisodes,
          );

          if (series != null) {
            final ep = series.episodes
                .where((e) => e.number == episodeNumber)
                .cast<AnikotoEpisode?>()
                .firstWhere((_) => true, orElse: () => null);

            if (ep != null && ep.embedId.isNotEmpty) {
              final cats = categoryFilter != null ? [categoryFilter] : ['sub', 'dub'];
              final anikotoTasks = <Future>[];

              for (final cat in cats) {
                // MegaPlay HD-1
                anikotoTasks.add(
                  _anikoto
                      .extractDirect(
                    host: 'megaplay.buzz',
                    embedId: ep.embedId,
                    category: cat,
                  )
                      .then((res) {
                    if (res != null &&
                        res.url.isNotEmpty &&
                        seenUrls.add(res.url) &&
                        !controller.isClosed) {
                      final catUpper = cat.toUpperCase();
                      controller.add(
                        StreamSource(
                          name: '⚡ MegaPlay (HD-1) • $catUpper',
                          title:
                              '${anime.displayTitle} • Ep $episodeNumber [MegaPlay HD-1 • $catUpper]',
                          description:
                              'MegaPlay • Master HLS • $catUpper • ${res.tracks.length} Subtitles',
                          url: res.url,
                          addonName: 'MegaPlay',
                          headers: {
                            'Referer': res.referer,
                            'Origin': res.origin,
                            'User-Agent':
                                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                          },
                          behaviorHints: {
                            'notWebReady': false,
                            'proxyHeaders': {
                              'request': {
                                'Referer': res.referer,
                                'Origin': res.origin,
                                'User-Agent':
                                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                              },
                            },
                          },
                        ),
                      );
                    }
                  }).catchError((_) {}),
                );

                // VidWish HD-2
                anikotoTasks.add(
                  _anikoto
                      .extractDirect(
                    host: 'vidwish.live',
                    embedId: ep.embedId,
                    category: cat,
                  )
                      .then((res) {
                    if (res != null &&
                        res.url.isNotEmpty &&
                        seenUrls.add(res.url) &&
                        !controller.isClosed) {
                      final catUpper = cat.toUpperCase();
                      controller.add(
                        StreamSource(
                          name: '⚡ VidWish (HD-2) • $catUpper',
                          title:
                              '${anime.displayTitle} • Ep $episodeNumber [VidWish HD-2 • $catUpper]',
                          description:
                              'VidWish • Master HLS • $catUpper • ${res.tracks.length} Subtitles',
                          url: res.url,
                          addonName: 'VidWish',
                          headers: {
                            'Referer': res.referer,
                            'Origin': res.origin,
                            'User-Agent':
                                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                          },
                          behaviorHints: {
                            'notWebReady': false,
                            'proxyHeaders': {
                              'request': {
                                'Referer': res.referer,
                                'Origin': res.origin,
                                'User-Agent':
                                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                              },
                            },
                          },
                        ),
                      );
                    }
                  }).catchError((_) {}),
                );
              }

              await Future.wait(anikotoTasks);
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[AnimeScraper] Anikoto extract error: $e');
        }
      }());

      // 2. AllAnime Extractor
      final allAnimeCats = categoryFilter != null ? [categoryFilter] : ['sub', 'dub'];
      for (final cat in allAnimeCats) {
        for (final prov in AllAnimeExtractor.knownProviders) {
          tasks.add(
            _allAnime
                .extractWithProvider(
              titleCandidates: titleCandidates,
              episodeNumber: episodeNumber,
              category: cat,
              provider: prov,
            )
                .then((res) {
              if (res != null &&
                  res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                final catUpper = cat.toUpperCase();
                final isHls = res.url.contains('.m3u8');
                final typeTag = isHls ? 'HLS' : 'MP4';
                controller.add(
                  StreamSource(
                    name: '⚡ AllAnime ($prov) • $catUpper',
                    title:
                        '${anime.displayTitle} • Ep $episodeNumber [AllAnime $prov • $catUpper]',
                    description: 'AllAnime • $prov • $typeTag • $catUpper',
                    url: res.url,
                    addonName: 'AllAnime',
                    headers: {
                      'Referer': res.referer,
                      'Origin': res.origin,
                      'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
                    },
                    behaviorHints: {
                      'notWebReady': false,
                      'proxyHeaders': {
                        'request': {
                          'Referer': res.referer,
                          'Origin': res.origin,
                          'User-Agent':
                              'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
                        },
                      },
                    },
                  ),
                );
              }
            }).catchError((_) {}),
          );
        }
      }

      // 3. Miruro Secure-Pipe Extractor
      final miruroCats = categoryFilter != null ? [categoryFilter] : ['sub', 'dub'];
      for (final cat in miruroCats) {
        for (final prov in MiruroExtractor.knownProviders) {
          tasks.add(
            _miruro
                .extractWithProvider(
              anilistId: anime.id,
              episodeNumber: episodeNumber,
              category: cat,
              provider: prov,
            )
                .then((res) {
              if (res != null &&
                  res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                final catUpper = cat.toUpperCase();
                final provUpper =
                    prov[0].toUpperCase() + (prov.length > 1 ? prov.substring(1) : '');
                controller.add(
                  StreamSource(
                    name: '⚡ Miruro ($provUpper) • $catUpper',
                    title:
                        '${anime.displayTitle} • Ep $episodeNumber [Miruro $provUpper • $catUpper]',
                    description:
                        'Miruro • $provUpper • HLS • $catUpper • ${res.tracks.length} Subtitles',
                    url: res.url,
                    addonName: 'Miruro',
                    headers: {
                      'Referer': res.referer,
                      'Origin': res.origin,
                      'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                    },
                    behaviorHints: {
                      'notWebReady': false,
                      'proxyHeaders': {
                        'request': {
                          'Referer': res.referer,
                          'Origin': res.origin,
                          'User-Agent':
                              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                        },
                      },
                    },
                  ),
                );
              }
            }).catchError((_) {}),
          );
        }
      }

      // 4. WatchHentai & Hentaini Extractor (if Adult/NSFW)
      final isAdultAnime = anime.genres.any((g) =>
          g.toLowerCase().contains('hentai') || g.toLowerCase().contains('erotica'));
      if (isAdultAnime && titleCandidates.isNotEmpty) {
        tasks.add(
          _watchHentai
              .extract(
            titleCandidates: titleCandidates,
            episodeNumber: episodeNumber,
          )
              .then((res) {
            if (res != null &&
                res.url.isNotEmpty &&
                seenUrls.add(res.url) &&
                !controller.isClosed) {
              controller.add(
                StreamSource(
                  name: '⚡ WatchHentai • HD',
                  title: '${anime.displayTitle} • Ep $episodeNumber [WatchHentai]',
                  description: 'WatchHentai • Direct Video',
                  url: res.url,
                  addonName: 'WatchHentai',
                  headers: {
                    'Referer': res.referer,
                    'Origin': res.origin,
                  },
                ),
              );
            }
          }).catchError((_) {}),
        );

        tasks.add(
          _hentaini
              .extract(
            titleCandidates: titleCandidates,
            episodeNumber: episodeNumber,
          )
              .then((res) {
            if (res != null &&
                res.url.isNotEmpty &&
                seenUrls.add(res.url) &&
                !controller.isClosed) {
              controller.add(
                StreamSource(
                  name: '⚡ Hentaini • HD',
                  title: '${anime.displayTitle} • Ep $episodeNumber [Hentaini]',
                  description: 'Hentaini • Direct Video',
                  url: res.url,
                  addonName: 'Hentaini',
                  headers: {
                    'Referer': res.referer,
                    'Origin': res.origin,
                  },
                ),
              );
            }
          }).catchError((_) {}),
        );
      }

      await Future.wait(tasks);
      if (!controller.isClosed) {
        controller.close();
      }
    }();

    return controller.stream;
  }

  /// Fetch all scraped stream sources as a list
  Future<List<StreamSource>> scrapeAllStreams({
    required AnimeMedia anime,
    required int episodeNumber,
    String? categoryFilter,
  }) async {
    final list = <StreamSource>[];
    await for (final source in scrapeStreamsStream(
      anime: anime,
      episodeNumber: episodeNumber,
      categoryFilter: categoryFilter,
    )) {
      list.add(source);
    }
    return list;
  }

  /// Converts AnimeMedia and Episode to MovieDetail and Video for the PlayerScreen
  static MovieDetail toMovieDetail(AnimeMedia anime) {
    return MovieDetail(
      id: 'anilist:${anime.id}',
      type: 'anime',
      name: anime.displayTitle,
      poster: anime.coverUrl,
      background: anime.backdropUrl,
      description: anime.description,
      year: anime.seasonYear > 0 ? '${anime.seasonYear}' : null,
      imdbRating: anime.averageScore > 0 ? anime.formattedScore : null,
      genres: anime.genres,
      videos: List.generate(
        anime.totalEpisodes > 0 ? anime.totalEpisodes : 24,
        (i) => Video(
          id: 'anilist:${anime.id}:${i + 1}',
          season: 1,
          episode: i + 1,
          title: 'Episode ${i + 1}',
          thumbnail: anime.backdropUrl,
        ),
      ),
    );
  }

  static Video toVideo(AnimeMedia anime, int episodeNumber) {
    return Video(
      id: 'anilist:${anime.id}:$episodeNumber',
      season: 1,
      episode: episodeNumber,
      title: 'Episode $episodeNumber',
      thumbnail: anime.backdropUrl,
    );
  }
}
