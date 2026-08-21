import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';
import 'tmdb_helper.dart';

/// Vuflix Stream Scraper for PlayTorrioHTTP.
///
/// Fetches all active streaming servers and mirrors from Vuflix (vuflix.co),
/// including 4K (Yoru/Cineplay), Sigma (VSEmbed), Upsilon (Bingr multi-audio),
/// Tau (FileSuN/VidMoly), Gamma (OnlyFlix/FlixHQz), Alpha (VAPlayer),
/// Beta (Huhu multi-language), and Pi (MovieBox MP4).
class VuflixScraper extends StreamScraper {
  @override
  String get name => 'PlayTorrioHTTP';

  static const _apiBase = 'https://vuflix.co';
  static const _referer = 'https://vuflix.co/';
  static const _origin = 'https://vuflix.co';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const _defaultHeaders = {
    'User-Agent': _ua,
    'Referer': _referer,
    'Origin': _origin,
    'Accept': 'application/json, text/plain, */*',
  };

  @override
  Stream<StreamSource> scrapeStream({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) {
    final controller = StreamController<StreamSource>();
    final isTv = (type == 'series' || type == 'tv');
    final mediaType = isTv ? 'tv' : 'movie';

    () async {
      try {
        final tmdbId = await TmdbHelper.resolveTmdbId(
          imdbId: imdbId,
          title: title,
          type: mediaType,
          year: year,
        );

        if (tmdbId == null || tmdbId <= 0) {
          debugPrint('[VuflixScraper] Could not resolve TMDb ID for "$title"');
          controller.close();
          return;
        }

        debugPrint(
            '[VuflixScraper] Starting scrape for "$title" (tmdb: $tmdbId, S:${season}E:$episode)');

        final qParams = StringBuffer('type=$mediaType&tmdbId=$tmdbId');
        if (isTv) {
          qParams.write('&season=${season ?? 1}&episode=${episode ?? 1}');
        }

        final uri = Uri.parse('$_apiBase/api/player/sources?${qParams.toString()}');
        final client = http.Client();
        final res = await client
            .get(uri, headers: _defaultHeaders)
            .timeout(const Duration(seconds: 15));

        if (res.statusCode != 200) {
          debugPrint('[VuflixScraper] HTTP ${res.statusCode} for "$title"');
          controller.close();
          return;
        }

        final data = jsonDecode(res.body);
        if (data is! Map || data['ok'] != true || data['sources'] is! List) {
          debugPrint('[VuflixScraper] No valid sources in response for "$title"');
          controller.close();
          return;
        }

        final sourcesList = data['sources'] as List;
        final seenUrls = <String>{};

        for (final item in sourcesList) {
          if (item is! Map) continue;

          final providerId = (item['provider'] ?? '').toString().toLowerCase();
          final providerName =
              (item['providerName'] ?? item['publicLabel'] ?? providerId).toString();
          final primaryUrl = (item['url'] ?? '').toString().trim();
          final itemType = (item['type'] ?? 'hls').toString().toLowerCase();
          final itemLanguage = (item['language'] ?? '').toString();
          final itemLabel = (item['label'] ?? '').toString();

          // 1. Check if source contains specific quality variants (e.g. 2160p 4K, 1080p, 720p)
          final qualities = item['qualities'];
          if (qualities is List && qualities.isNotEmpty) {
            for (final q in qualities) {
              if (q is! Map) continue;
              final qUrl = (q['url'] ?? '').toString().trim();
              if (qUrl.isEmpty || seenUrls.contains(qUrl)) continue;
              seenUrls.add(qUrl);

              final qQuality = (q['quality'] ?? 'Auto').toString();
              final qType = (q['type'] ?? itemType).toString().toUpperCase();
              final streamTitle = '[Vuflix - $providerName] $qQuality';
              final desc = '$providerName • $qQuality • $qType';

              controller.add(
                _buildSource(
                  url: qUrl,
                  title: streamTitle,
                  quality: qQuality,
                  description: desc,
                ),
              );
            }
          }

          // 2. Check if source contains candidate mirrors (e.g. Alpha mirror 1, 2, 3)
          final candidates = item['candidates'];
          if (candidates is List && candidates.isNotEmpty) {
            var candIndex = 1;
            for (final c in candidates) {
              if (c is! Map) continue;
              final cUrl = (c['url'] ?? '').toString().trim();
              if (cUrl.isEmpty || seenUrls.contains(cUrl)) continue;
              seenUrls.add(cUrl);

              final cQuality = (c['quality'] ?? '1080p').toString();
              final cType = (c['type'] ?? itemType).toString().toUpperCase();
              final streamTitle =
                  '[Vuflix - $providerName] Mirror $candIndex • $cQuality';
              final desc = '$providerName Mirror $candIndex • $cType';
              candIndex++;

              controller.add(
                _buildSource(
                  url: cUrl,
                  title: streamTitle,
                  quality: cQuality,
                  description: desc,
                ),
              );
            }
          }

          // 3. Check if source contains multi-language tracks with switchable URLs
          final audioTracks = item['audioTracks'];
          if (audioTracks is List && audioTracks.isNotEmpty) {
            for (final a in audioTracks) {
              if (a is! Map) continue;
              final aUrl = (a['switchUrl'] ?? a['url'] ?? '').toString().trim();
              if (aUrl.isEmpty || seenUrls.contains(aUrl)) continue;
              seenUrls.add(aUrl);

              final aLabel = (a['label'] ?? a['name'] ?? a['language'] ?? 'Audio').toString();
              final streamTitle = '[Vuflix - $providerName] $aLabel Audio';
              final desc = '$providerName • $aLabel Audio • ${itemType.toUpperCase()}';

              controller.add(
                _buildSource(
                  url: aUrl,
                  title: streamTitle,
                  quality: 'HD',
                  description: desc,
                ),
              );
            }
          }

          // 4. Primary URL fallback if not already emitted
          if (primaryUrl.isNotEmpty && !seenUrls.contains(primaryUrl)) {
            seenUrls.add(primaryUrl);

            var displayQuality = (item['quality'] ?? '').toString();
            if (displayQuality.isEmpty) {
              displayQuality = itemType == 'mp4' ? 'MP4' : 'HD';
            }

            var cleanLabel = itemLabel;
            if (cleanLabel.isEmpty) {
              cleanLabel = providerName;
            }

            final streamTitle = cleanLabel.startsWith('[')
                ? cleanLabel
                : '[Vuflix - $providerName] $displayQuality';
            final desc = itemLanguage.isNotEmpty
                ? '$providerName • $itemLanguage • ${itemType.toUpperCase()}'
                : '$providerName • ${itemType.toUpperCase()}';

            controller.add(
              _buildSource(
                url: primaryUrl,
                title: streamTitle,
                quality: displayQuality,
                description: desc,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[VuflixScraper] Error scraping "$title": $e');
      } finally {
        controller.close();
      }
    }();

    return controller.stream;
  }

  StreamSource _buildSource({
    required String url,
    required String title,
    required String quality,
    required String description,
  }) {
    return StreamSource(
      name: title,
      title: title,
      description: description,
      url: url,
      addonName: 'PlayTorrioHTTP',
      headers: {
        'User-Agent': _ua,
        'Referer': _referer,
        'Origin': _origin,
      },
      behaviorHints: {
        'notWebReady': false,
        'proxyHeaders': {
          'request': {
            'User-Agent': _ua,
            'Referer': _referer,
            'Origin': _origin,
          },
        },
      },
    );
  }
}
