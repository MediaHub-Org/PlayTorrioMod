import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/addon/addon.dart';
import '../models/movie/movie.dart';
import '../models/movie/movie_section.dart';
import '../models/my_list/my_list_item.dart';
import 'metadata/bestsimilar_scraper.dart';
import 'my_list/my_list_service.dart';

enum SimilarSectionPosition {
  top('Top (Below Hero Banner)'),
  underCinemeta('Under Cinemeta Addon'),
  middle('Middle of Catalog'),
  bottom('Bottom of Page');

  final String label;
  const SimilarSectionPosition(this.label);
}

enum HeroStyle {
  immersive('Immersive Cinematic Carousel'),
  compact('Compact Spotlight'),
  minimalist('Minimalist Header');

  final String label;
  const HeroStyle(this.label);
}

enum AmbientLightPattern {
  dualOrbs('Dual Floating Orbs'),
  topAurora('Top Aurora Horizon'),
  fullMesh('Full Deep Ambient Mesh'),
  centerPulse('Pulsing Core');

  final String label;
  const AmbientLightPattern(this.label);
}

enum CardDensity {
  compact('Compact (Dense Grid)'),
  standard('Standard Balanced'),
  cinematic('Cinematic (Large Posters)');

  final String label;
  const CardDensity(this.label);
}

abstract final class HomePageSettings {
  static const _keyEnableSpotlight = 'home_enable_spotlight';
  static const _keyEnableSimilar = 'home_enable_similar';
  static const _keySimilarPosition = 'home_similar_position';
  static const _keyHeroStyle = 'home_hero_style';
  static const _keyHeroAutoRotate = 'home_hero_auto_rotate';
  static const _keyHeroRotateSeconds = 'home_hero_rotate_seconds';
  static const _keyCardDensity = 'home_card_density';
  static const _keyShowRating = 'home_show_rating';
  static const _keyAmbientGlow = 'home_ambient_glow';
  static const _keyCardHoverZoom = 'home_card_hover_zoom';
  static const _keyEnableAmbientLights = 'home_enable_ambient_lights';
  static const _keyAmbientPattern = 'home_ambient_pattern';
  static const _keyAmbientIntensity = 'home_ambient_intensity';
  static const _keyAmbientSpeed = 'home_ambient_speed';

  static final ValueNotifier<bool> enableSpotlight = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> enableSimilar = ValueNotifier<bool>(true);
  static final ValueNotifier<SimilarSectionPosition> similarPosition =
      ValueNotifier<SimilarSectionPosition>(SimilarSectionPosition.top);
  static final ValueNotifier<HeroStyle> heroStyle =
      ValueNotifier<HeroStyle>(HeroStyle.immersive);
  static final ValueNotifier<bool> heroAutoRotate = ValueNotifier<bool>(true);
  static final ValueNotifier<int> heroRotateSeconds = ValueNotifier<int>(6);
  static final ValueNotifier<CardDensity> cardDensity =
      ValueNotifier<CardDensity>(CardDensity.standard);
  static final ValueNotifier<bool> showRating = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> ambientGlow = ValueNotifier<bool>(true);
  static final ValueNotifier<double> cardHoverZoom = ValueNotifier<double>(1.08);
  static final ValueNotifier<bool> enableAmbientLights = ValueNotifier<bool>(true);
  static final ValueNotifier<AmbientLightPattern> ambientLightPattern =
      ValueNotifier<AmbientLightPattern>(AmbientLightPattern.dualOrbs);
  static final ValueNotifier<double> ambientLightIntensity =
      ValueNotifier<double>(0.22);
  static final ValueNotifier<double> ambientLightSpeed =
      ValueNotifier<double>(1.0);

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  // Cached recommendation section to avoid scraping on every scroll
  static MovieSection? _cachedSimilarSection;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    enableSpotlight.value = prefs.getBool(_keyEnableSpotlight) ?? true;
    enableSimilar.value = prefs.getBool(_keyEnableSimilar) ?? true;

    final posStr = prefs.getString(_keySimilarPosition);
    similarPosition.value = SimilarSectionPosition.values.firstWhere(
      (p) => p.name == posStr,
      orElse: () => SimilarSectionPosition.top,
    );

    final heroStr = prefs.getString(_keyHeroStyle);
    heroStyle.value = HeroStyle.values.firstWhere(
      (h) => h.name == heroStr,
      orElse: () => HeroStyle.immersive,
    );

    heroAutoRotate.value = prefs.getBool(_keyHeroAutoRotate) ?? true;
    heroRotateSeconds.value = prefs.getInt(_keyHeroRotateSeconds) ?? 6;

    final densityStr = prefs.getString(_keyCardDensity);
    cardDensity.value = CardDensity.values.firstWhere(
      (d) => d.name == densityStr,
      orElse: () => CardDensity.standard,
    );

    showRating.value = prefs.getBool(_keyShowRating) ?? true;
    ambientGlow.value = prefs.getBool(_keyAmbientGlow) ?? true;
    cardHoverZoom.value = prefs.getDouble(_keyCardHoverZoom) ?? 1.08;

    enableAmbientLights.value = prefs.getBool(_keyEnableAmbientLights) ?? true;
    final patternStr = prefs.getString(_keyAmbientPattern);
    ambientLightPattern.value = AmbientLightPattern.values.firstWhere(
      (p) => p.name == patternStr,
      orElse: () => AmbientLightPattern.dualOrbs,
    );
    ambientLightIntensity.value = prefs.getDouble(_keyAmbientIntensity) ?? 0.22;
    ambientLightSpeed.value = prefs.getDouble(_keyAmbientSpeed) ?? 1.0;
  }

  static Future<void> setEnableAmbientLights(bool val) async {
    enableAmbientLights.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableAmbientLights, val);
    changeNotifier.value++;
  }

  static Future<void> setAmbientLightPattern(AmbientLightPattern pattern) async {
    ambientLightPattern.value = pattern;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAmbientPattern, pattern.name);
    changeNotifier.value++;
  }

  static Future<void> setAmbientLightIntensity(double val) async {
    ambientLightIntensity.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyAmbientIntensity, val);
    changeNotifier.value++;
  }

  static Future<void> setAmbientLightSpeed(double val) async {
    ambientLightSpeed.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyAmbientSpeed, val);
    changeNotifier.value++;
  }

  static Future<void> setEnableSpotlight(bool val) async {
    enableSpotlight.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableSpotlight, val);
    changeNotifier.value++;
  }

  static Future<void> setEnableSimilar(bool val) async {
    enableSimilar.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableSimilar, val);
    changeNotifier.value++;
  }

  static Future<void> setSimilarPosition(SimilarSectionPosition pos) async {
    similarPosition.value = pos;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySimilarPosition, pos.name);
    changeNotifier.value++;
  }

  static Future<void> setHeroStyle(HeroStyle style) async {
    heroStyle.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHeroStyle, style.name);
    changeNotifier.value++;
  }

  static Future<void> setHeroAutoRotate(bool val) async {
    heroAutoRotate.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHeroAutoRotate, val);
    changeNotifier.value++;
  }

  static Future<void> setHeroRotateSeconds(int seconds) async {
    heroRotateSeconds.value = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHeroRotateSeconds, seconds);
    changeNotifier.value++;
  }

  static Future<void> setCardDensity(CardDensity density) async {
    cardDensity.value = density;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCardDensity, density.name);
    changeNotifier.value++;
  }

  static Future<void> setShowRating(bool val) async {
    showRating.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowRating, val);
    changeNotifier.value++;
  }

  static Future<void> setAmbientGlow(bool val) async {
    ambientGlow.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAmbientGlow, val);
    changeNotifier.value++;
  }

  static Future<void> setCardHoverZoom(double zoom) async {
    cardHoverZoom.value = zoom;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyCardHoverZoom, zoom);
    changeNotifier.value++;
  }

  /// Fetches a dynamic "Because you have [Title] on your list" section using BestSimilar
  static Future<MovieSection?> fetchBestSimilarSection({bool forceRefresh = false}) async {
    if (!enableSimilar.value) return null;

    final myList = MyListService.items.value;
    if (myList.isEmpty) return null;

    if (!forceRefresh && _cachedSimilarSection != null) {
      return _cachedSimilarSection;
    }

    // Try candidates from My List (latest added first, with fallback to others)
    final candidates = List<MyListItem>.from(myList.reversed);

    for (final sourceItem in candidates) {
      try {
        final hit = await BestSimilarScraper.findBest(
          title: sourceItem.title,
          year: sourceItem.year,
          isTv: sourceItem.type == 'series' || sourceItem.type == 'tv',
        );

        if (hit == null) continue;

        final details = await BestSimilarScraper.fetchDetails(
          id: hit.id,
          slug: hit.slug,
        );

        if (details == null || details.similar.isEmpty) continue;

        // Safety Guard: If source title is live-action, don't allow anime details
        final isAnimeSource = sourceItem.type == 'anime' ||
            sourceItem.title.toLowerCase().contains('anime');
        final isAnimeMatched = (details.genre?.toLowerCase().contains('animation') == true ||
                details.genre?.toLowerCase().contains('anime') == true) &&
            details.plotTags.any((t) =>
                t.toLowerCase() == 'anime' ||
                t.toLowerCase() == 'japanese animation' ||
                t.toLowerCase() == 'manga adaptation');

        if (!isAnimeSource && isAnimeMatched) {
          debugPrint('[HomePageSettings] Skipping anime match for live-action: ${sourceItem.title}');
          continue;
        }

        final movies = <Movie>[];
        for (final sim in details.similar.take(24)) {
          movies.add(Movie(
            id: 'bestsimilar_${sim.id}',
            type: sim.slug.contains('serial') ? 'series' : 'movie',
            name: sim.title,
            poster: sim.thumbUrl,
            year: sim.year?.toString(),
            addonBaseUrl: 'https://v3-cinemeta.strem.io',
          ));
        }

        if (movies.isEmpty) continue;

        final section = MovieSection(
          title: 'Because you have "${sourceItem.title}" on your list',
          subtitle: 'Recommendations based on ${sourceItem.title}',
          contentType: sourceItem.type,
          addonBaseUrl: 'https://v3-cinemeta.strem.io',
          catalog: AddonCatalog(
            type: sourceItem.type,
            id: 'bestsimilar',
            name: 'Similar to ${sourceItem.title}',
            genres: const [],
            supportsSearch: false,
            supportsSkip: false,
          ),
          movies: movies,
        );

        _cachedSimilarSection = section;
        return section;
      } catch (e) {
        debugPrint('[HomePageSettings] Candidate ${sourceItem.title} failed: $e');
      }
    }

    return null;
  }
}
