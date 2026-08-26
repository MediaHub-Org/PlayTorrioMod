import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AnikotoEpisode {
  final int id;
  final int number;
  final String title;
  final String embedId;

  const AnikotoEpisode({
    required this.id,
    required this.number,
    required this.title,
    required this.embedId,
  });

  factory AnikotoEpisode.fromJson(Map<String, dynamic> j) {
    return AnikotoEpisode(
      id: (j['id'] ?? 0) as int,
      number: (j['number'] ?? 0) as int,
      title: (j['title'] ?? '') as String,
      embedId: (j['episode_embed_id'] ?? '').toString(),
    );
  }
}

class AnikotoSeries {
  final int id;
  final List<AnikotoEpisode> episodes;
  const AnikotoSeries({required this.id, required this.episodes});
}

class _AnikotoCandidate {
  final String slug;
  final int id;
  final int episodes;
  const _AnikotoCandidate({required this.slug, required this.id, this.episodes = 0});
}

class AnikotoTrack {
  final String url;
  final String label;
  final bool isDefault;
  const AnikotoTrack({
    required this.url,
    required this.label,
    this.isDefault = false,
  });
}

class AnikotoDirectResult {
  final String url;
  final String referer;
  final String origin;
  final List<AnikotoTrack> tracks;
  final int? introStart;
  final int? introEnd;
  final int? outroStart;
  final int? outroEnd;

  const AnikotoDirectResult({
    required this.url,
    required this.referer,
    required this.origin,
    this.tracks = const [],
    this.introStart,
    this.introEnd,
    this.outroStart,
    this.outroEnd,
  });
}

class AnikotoResolver {
  static final AnikotoResolver instance = AnikotoResolver._internal();
  AnikotoResolver._internal();

  static const String embedReferer = 'https://www.enma.lol/';

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  final Map<int, AnikotoSeries?> _cache = {};

  static const _stopwords = <String>{
    'the', 'a', 'an', 'of', 'and', 'or', 'to', 'in', 'on',
    'no', 'wa', 'ga', 'ni', 'wo', 'de', 'mo',
    'season', 'part', 'arc', 'tv', 'special', 'ova', 'ona',
  };

  Set<String> _slugTokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 1)
      .toSet();

  Future<AnikotoSeries?> resolveAnikoto({
    required int anilistId,
    required List<String> titleCandidates,
    int? expectedEpisodes,
  }) async {
    if (_cache.containsKey(anilistId)) return _cache[anilistId];
    final s = await _findSeries(
      anilistId: anilistId,
      titles: titleCandidates,
      expectedEpisodes: expectedEpisodes,
    );
    _cache[anilistId] = s;
    return s;
  }

  Future<AnikotoSeries?> _findSeries({
    required int anilistId,
    required List<String> titles,
    int? expectedEpisodes,
  }) async {
    // Strategy A: recent feed
    const int maxPages = 4;
    const int perPage = 60;
    for (var page = 1; page <= maxPages; page++) {
      try {
        final list = await _anikotoGet('/recent-anime?page=$page&per_page=$perPage');
        final data = (list?['data'] as List?) ?? const [];
        for (final raw in data) {
          final m = (raw as Map).cast<String, dynamic>();
          final ani = (m['ani_id'] ?? '').toString();
          if (ani == anilistId.toString()) {
            return _loadSeries(m['id'] as int);
          }
        }
        if (data.length < perPage) break;
      } catch (_) {
        break;
      }
    }

    // Strategy B: search anikototv.to
    final candidates = <String>{};
    final queries = <String>{};
    for (final raw in titles) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      queries.add(t);
      final clean = t
          .replaceAll(RegExp(r'[:\-~–—].+$'), '')
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'\[[^\]]*\]'), '')
          .trim();
      if (clean.isNotEmpty) queries.add(clean);
      final withoutSeason = clean
          .replaceAll(RegExp(r'\b(season|part|cour)\s*\d+\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b\d+(nd|rd|th|st)\s*season\b', caseSensitive: false), '')
          .trim();
      if (withoutSeason.isNotEmpty) queries.add(withoutSeason);
    }

    for (final q in queries) {
      candidates.addAll(await _searchSlugs(q));
      if (candidates.length >= 10) break;
    }

    final probe = candidates.take(8).toList();
    final resolved = <_AnikotoCandidate>[];
    final aniIdMatches = <_AnikotoCandidate>[];

    for (final slug in probe) {
      final id = await _idFromSlug(slug);
      if (id == null) continue;
      try {
        final j = await _anikotoGet('/series/$id');
        final aniId = (j?['data']?['anime']?['ani_id'] ?? '').toString();
        final epCount = (j?['data']?['episodes'] as List?)?.length ?? 0;
        final cand = _AnikotoCandidate(slug: slug, id: id, episodes: epCount);
        if (aniId == anilistId.toString()) {
          aniIdMatches.add(cand);
        } else {
          resolved.add(cand);
        }
      } catch (_) {}
    }

    if (aniIdMatches.isNotEmpty) {
      final expected = expectedEpisodes ?? 0;
      if (expected > 0) {
        aniIdMatches.sort((a, b) {
          final da = (a.episodes - expected).abs();
          final db = (b.episodes - expected).abs();
          if (da != db) return da.compareTo(db);
          return b.episodes.compareTo(a.episodes);
        });
        final best = aniIdMatches.first;
        if (best.episodes >= (expected / 2).ceil() || resolved.isEmpty) {
          return _loadSeries(best.id);
        }
      } else {
        aniIdMatches.sort((a, b) => b.episodes.compareTo(a.episodes));
        return _loadSeries(aniIdMatches.first.id);
      }
    }

    // Strategy C: fuzzy match on slugs
    if (resolved.isNotEmpty) {
      final queryTokenSets = queries
          .map((q) => _slugTokens(q)..removeWhere(_stopwords.contains))
          .where((s) => s.isNotEmpty)
          .toList();

      if (queryTokenSets.isNotEmpty) {
        _AnikotoCandidate? best;
        double bestScore = 0;
        for (final c in resolved) {
          final slugTokens = c.slug
              .split('-')
              .where((t) => t.length > 1 && !RegExp(r'^[a-z0-9]{5}$').hasMatch(t))
              .toSet()
            ..removeWhere(_stopwords.contains);
          if (slugTokens.isEmpty) continue;

          for (final qTokens in queryTokenSets) {
            final inter = slugTokens.intersection(qTokens).length;
            if (inter == 0) continue;
            final union = slugTokens.length + qTokens.length - inter;
            final j = inter / union;
            if (j > bestScore) {
              bestScore = j;
              best = c;
            }
          }
        }
        if (best != null && bestScore >= 0.35) {
          return _loadSeries(best.id);
        }
      }
    }
    return null;
  }

  Future<List<String>> _searchSlugs(String query) async {
    try {
      final uri = Uri.parse(
          'https://anikototv.to/search?keyword=${Uri.encodeQueryComponent(query)}');
      final req = await _client.getUrl(uri);
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      req.headers.set('Accept', 'text/html');
      final res = await req.close();
      if (res.statusCode != 200) return const [];
      final html = await res.transform(utf8.decoder).join();
      final matches = RegExp(r'/watch/([a-z0-9-]+)').allMatches(html);
      final seen = <String>{};
      for (final m in matches) {
        final slug = m.group(1)!;
        if (seen.add(slug) && seen.length >= 12) break;
      }
      return seen.toList();
    } catch (_) {
      return const [];
    }
  }

  Future<int?> _idFromSlug(String slug) async {
    try {
      final uri = Uri.parse('https://anikototv.to/watch/$slug');
      final req = await _client.getUrl(uri);
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      req.headers.set('Accept', 'text/html');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final html = await res.transform(utf8.decoder).join();
      final m = RegExp(r'data-id="(\d+)"').firstMatch(html);
      if (m == null) return null;
      return int.tryParse(m.group(1)!);
    } catch (_) {
      return null;
    }
  }

  Future<AnikotoSeries?> _loadSeries(int anikotoId) async {
    try {
      final j = await _anikotoGet('/series/$anikotoId');
      final eps = ((j?['data']?['episodes'] as List?) ?? const [])
          .cast<Map>()
          .map((e) => AnikotoEpisode.fromJson(e.cast<String, dynamic>()))
          .toList();
      return AnikotoSeries(id: anikotoId, episodes: eps);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _anikotoGet(String path) async {
    try {
      final req = await _client.getUrl(Uri.parse('https://anikotoapi.site$path'));
      req.headers.set('Accept', 'application/json');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final j = jsonDecode(body);
      if (j is Map) return j.cast<String, dynamic>();
    } catch (_) {}
    return null;
  }

  /// Extract direct stream from MegaPlay (host = 'megaplay.buzz') or VidWish (host = 'vidwish.live').
  Future<AnikotoDirectResult?> extractDirect({
    required String host,
    required String embedId,
    required String category, // 'sub' | 'dub'
  }) async {
    try {
      final origin = 'https://$host';
      final embedUrl = '$origin/stream/s-2/$embedId/$category?autoPlay=1';

      // Step 1: get data-id
      final pageReq = await _client.getUrl(Uri.parse(embedUrl));
      pageReq.headers
        ..set('Referer', embedReferer)
        ..set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36')
        ..set('Accept',
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      final pageRes = await pageReq.close();
      if (pageRes.statusCode != 200) return null;

      final html = await pageRes.transform(utf8.decoder).join();
      final m = RegExp(r'data-id\s*=\s*"(\d+)"').firstMatch(html);
      if (m == null) return null;
      final dataId = m.group(1)!;

      // Step 2: fetch getSources
      final apiUri = Uri.parse('$origin/stream/getSources?id=$dataId');
      final apiReq = await _client.getUrl(apiUri);
      apiReq.headers
        ..set('Referer', embedUrl)
        ..set('Origin', origin)
        ..set('X-Requested-With', 'XMLHttpRequest')
        ..set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36')
        ..set('Accept', 'application/json, text/plain, */*');
      final apiRes = await apiReq.close();
      if (apiRes.statusCode != 200) return null;

      final body = await apiRes.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      if (json is! Map) return null;

      final file = (json['sources'] is Map ? json['sources']['file'] : null) as String?;
      if (file == null || file.isEmpty) return null;

      final tracks = <AnikotoTrack>[];
      final rawTracks = json['tracks'];
      if (rawTracks is List) {
        for (final t in rawTracks) {
          if (t is Map &&
              t['file'] is String &&
              ((t['kind'] ?? 'captions') == 'captions' ||
                  (t['kind'] ?? '') == 'subtitles')) {
            tracks.add(AnikotoTrack(
              url: t['file'] as String,
              label: (t['label'] as String?) ?? 'Unknown',
              isDefault: t['default'] == true,
            ));
          }
        }
      }

      int? introStart;
      int? introEnd;
      int? outroStart;
      int? outroEnd;

      if (json['intro'] is Map) {
        introStart = (json['intro']['start'] as num?)?.toInt();
        introEnd = (json['intro']['end'] as num?)?.toInt();
      }
      if (json['outro'] is Map) {
        outroStart = (json['outro']['start'] as num?)?.toInt();
        outroEnd = (json['outro']['end'] as num?)?.toInt();
      }

      return AnikotoDirectResult(
        url: file,
        referer: 'https://megaplay.buzz/',
        origin: 'https://megaplay.buzz',
        tracks: tracks,
        introStart: introStart,
        introEnd: introEnd,
        outroStart: outroStart,
        outroEnd: outroEnd,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AnikotoDirect] $host extract error: $e');
      return null;
    }
  }
}
