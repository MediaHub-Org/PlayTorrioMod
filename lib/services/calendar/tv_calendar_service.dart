import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TvCalendarEntryModel {
  final String showTitle;
  final String episodeTitle;
  final int seasonNumber;
  final int episodeNumber;
  final DateTime airDateTimeLocal;
  final String? airTimeFormatted;
  final String? overview;
  final String? imdbId;
  final String? posterUrl;
  final String? network;
  final double? rating;

  const TvCalendarEntryModel({
    required this.showTitle,
    required this.episodeTitle,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.airDateTimeLocal,
    this.airTimeFormatted,
    this.overview,
    this.imdbId,
    this.posterUrl,
    this.network,
    this.rating,
  });

  String get episodeCode =>
      'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}';
}

class TvCalendarService {
  TvCalendarService._();
  static final TvCalendarService instance = TvCalendarService._();

  final Map<String, List<TvCalendarEntryModel>> _dayCache = {};

  void invalidate() {
    _dayCache.clear();
  }

  /// Returns upcoming calendar days starting from today (21 days ahead).
  List<DateTime> getAiringDays({int daysAhead = 21}) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final days = <DateTime>[];

    for (int i = 0; i < daysAhead; i++) {
      days.add(startOfToday.add(Duration(days: i)));
    }
    return days;
  }

  /// Fetches episodes airing on the given date using TVMaze public API.
  Future<List<TvCalendarEntryModel>> getEpisodesForDay(
    DateTime day, {
    String query = '',
    bool forceRefresh = false,
  }) async {
    final dateKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    if (!forceRefresh && _dayCache.containsKey(dateKey)) {
      final cached = _dayCache[dateKey]!;
      return _filterEntries(cached, query);
    }

    try {
      final networkFuture = _fetchTvMazeSchedule('https://api.tvmaze.com/schedule?date=$dateKey', day);
      final webFuture = _fetchTvMazeSchedule('https://api.tvmaze.com/schedule/web?date=$dateKey', day);

      final results = await Future.wait([networkFuture, webFuture]);
      final combined = <TvCalendarEntryModel>[...results[0], ...results[1]];

      // De-duplicate by title + season + episode
      final seen = <String>{};
      final unique = <TvCalendarEntryModel>[];

      for (final entry in combined) {
        final key = '${entry.showTitle.toLowerCase()}-${entry.seasonNumber}-${entry.episodeNumber}';
        if (seen.add(key)) {
          unique.add(entry);
        }
      }

      // Sort by rating / popularity / airtime
      unique.sort((a, b) {
        if (a.posterUrl != null && b.posterUrl == null) return -1;
        if (a.posterUrl == null && b.posterUrl != null) return 1;
        return a.airDateTimeLocal.compareTo(b.airDateTimeLocal);
      });

      _dayCache[dateKey] = unique;
      return _filterEntries(unique, query);
    } catch (e) {
      debugPrint('[TvCalendarService] Error fetching schedule for $dateKey: $e');
      return const [];
    }
  }

  List<TvCalendarEntryModel> _filterEntries(List<TvCalendarEntryModel> list, String query) {
    if (query.trim().isEmpty) return list;
    final q = query.toLowerCase();
    return list.where((e) {
      return e.showTitle.toLowerCase().contains(q) ||
          e.episodeTitle.toLowerCase().contains(q);
    }).toList();
  }

  Future<List<TvCalendarEntryModel>> _fetchTvMazeSchedule(String url, DateTime targetDay) async {
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) return const [];

      final list = <TvCalendarEntryModel>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final show = item['_embedded']?['show'] ?? item['show'] as Map?;
        if (show == null) continue;

        final showTitle = (show['name'] as String?) ?? 'Unknown Show';
        final epTitle = (item['name'] as String?) ?? 'Episode';
        final season = (item['season'] as int?) ?? 1;
        final number = (item['number'] as int?) ?? 1;
        final airtimeStr = (item['airtime'] as String?) ?? '';
        final airstampStr = (item['airstamp'] as String?);

        DateTime localAirDate = targetDay;
        if (airstampStr != null && airstampStr.isNotEmpty) {
          final parsed = DateTime.tryParse(airstampStr);
          if (parsed != null) localAirDate = parsed.toLocal();
        }

        final summary = _cleanHtml(item['summary'] ?? show['summary']);
        final imdb = show['externals']?['imdb'] as String?;

        final imageMap = item['image'] as Map? ?? show['image'] as Map?;
        String? posterUrl = (imageMap?['original'] ?? imageMap?['medium']) as String?;
        if ((posterUrl == null || posterUrl.isEmpty) && imdb != null && imdb.isNotEmpty) {
          posterUrl = 'https://images.metahub.space/poster/medium/$imdb/img.jpg';
        }

        final network = show['network']?['name'] ?? show['webChannel']?['name'] as String?;
        final ratingVal = (show['rating']?['average'] as num?)?.toDouble();

        list.add(
          TvCalendarEntryModel(
            showTitle: showTitle,
            episodeTitle: epTitle,
            seasonNumber: season,
            episodeNumber: number,
            airDateTimeLocal: localAirDate,
            airTimeFormatted: airtimeStr.isNotEmpty ? _formatTimeStr(airtimeStr) : null,
            overview: summary,
            imdbId: imdb,
            posterUrl: posterUrl,
            network: network,
            rating: ratingVal,
          ),
        );
      }

      return list;
    } catch (e) {
      debugPrint('[TvCalendarService] Sub-fetch failed for $url: $e');
      return const [];
    }
  }

  String? _cleanHtml(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    final clean = s.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return clean.isNotEmpty ? clean : null;
  }

  String _formatTimeStr(String raw) {
    try {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1].padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        return '$displayHour:$minute $period';
      }
    } catch (_) {}
    return raw;
  }
}
