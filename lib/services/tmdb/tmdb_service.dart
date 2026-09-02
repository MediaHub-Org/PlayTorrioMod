import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/movie/cast_member.dart';
import 'tmdb_settings.dart';

/// Fetches cast (photos, character names) from TMDB to fill in what most
/// Stremio addons don't provide -- they typically send `cast` as plain name
/// strings, no photos. Falls back to the app's own bundled key so this works
/// out of the box like upstream; Settings > TMDB lets a user override it with
/// their own.
abstract final class TmdbService {
  static const _baseUrl = 'https://api.themoviedb.org/3';

  // Same public key bundled in `scraper/sites/tmdb_helper.dart` -- kept here
  // too rather than importing across that layer boundary for one constant.
  static const _bundledApiKey = 'b3556f3b206e16f82df4d1f6fd4545e6';

  /// Fetches the cast for a movie or TV show by its TMDB id. Returns an
  /// empty list if the id is invalid or the request fails -- callers should
  /// keep whatever cast data they already have in that case.
  static Future<List<CastMember>> fetchCast(
    String tmdbId, {
    required bool isTvShow,
  }) async {
    final key = TmdbSettings.apiKey.value ?? _bundledApiKey;
    if (tmdbId.isEmpty) return const [];

    final kind = isTvShow ? 'tv' : 'movie';
    final uri = Uri.parse(
      '$_baseUrl/$kind/$tmdbId/credits',
    ).replace(queryParameters: {'api_key': key});

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];

      final body = jsonDecode(response.body);
      final cast = body is Map ? body['cast'] : null;
      if (cast is! List) return const [];

      return cast
          .whereType<Map>()
          .map((c) => CastMember.fromJson(c.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('[TmdbService] fetchCast failed: $e');
      return const [];
    }
  }
}
