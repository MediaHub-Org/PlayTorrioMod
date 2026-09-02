import '../../../utils/torrent/parse_torrent_title.dart';

class DebridMediaMatcher {
  static final _ptt = ParseTorrentTitle();

  static const _videoExts = {
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.webm',
    '.ts',
    '.m4v',
    '.flv',
    '.wmv',
    '.iso',
  };

  static const _audioExts = {
    '.mp3',
    '.m4b',
    '.m4a',
    '.aac',
    '.flac',
    '.ogg',
    '.opus',
    '.wav',
    '.wma',
  };

  static final _junkRegex = RegExp(
    r'(?:[\b._\-/]sample[\b._\-/]|[\b._\-/]trailer[\b._\-/]|[\b._\-/]extras?[\b._\-/]|[\b._\-/]bonus[\b._\-/]|[\b._\-/]featurettes?[\b._\-/]|[\b._\-/]deleted[._ -]scenes?[\b._\-/]|behind[._ -]the[._ -]scenes|preview|interview)',
    caseSensitive: false,
  );

  /// Checks if a file path or filename matches the requested season and episode.
  static bool isFileMatch(
    String rawPath,
    int targetSeason,
    int targetEpisode, {
    String? episodeTitle,
  }) {
    return computeFileMatchScore(
          rawPath,
          1024 * 1024 * 1000,
          season: targetSeason,
          episode: targetEpisode,
          episodeTitle: episodeTitle,
        ) >
        500.0;
  }

  /// Calculates a comprehensive match score for a torrent file candidate.
  static double computeFileMatchScore(
    String rawPath,
    int sizeBytes, {
    int? season,
    int? episode,
    String? episodeTitle,
    String? filename,
  }) {
    double score = 0.0;
    final lowerPath = rawPath.toLowerCase();

    // 1. Strict Penalty for Samples, Trailers, and Extras
    if (_junkRegex.hasMatch(lowerPath) ||
        lowerPath.endsWith('.sample') ||
        lowerPath.contains('sample.')) {
      score -= 5000.0;
    }

    // 2. File size weight: larger files are full releases, not short clips
    final sizeGB = sizeBytes / (1024.0 * 1024.0 * 1024.0);
    score += (sizeGB * 25.0).clamp(0.0, 100.0);

    if (sizeBytes < 25 * 1024 * 1024 && !_audioExts.any((ext) => lowerPath.endsWith(ext))) {
      score -= 2000.0; // Stubs, previews, or sample files
    }

    // 3. Season & Episode Matching
    if (season != null && episode != null) {
      final parsed = _ptt.parsePath(rawPath);
      final parsedSeason = parsed['season'] as int?;
      final parsedEpisode = parsed['episode'] as int?;
      final episodeRange = parsed['episodeRange'] as List<int>?;

      // Exact Season & Episode Match
      if (parsedSeason == season && parsedEpisode == episode) {
        score += 1500.0;
      }
      // Multi-Episode File Range Match (e.g. S01E01-E04 for Ep 2)
      else if (parsedSeason == season &&
          episodeRange != null &&
          episode >= episodeRange[0] &&
          episode <= episodeRange[1]) {
        score += 1400.0;
      }
      // Single-Season Pack (Season omitted in filename, but episode matches)
      else if (parsedSeason == null && parsedEpisode == episode) {
        score += 1250.0;
      }
      // Range match without explicit season
      else if (parsedSeason == null &&
          episodeRange != null &&
          episode >= episodeRange[0] &&
          episode <= episodeRange[1]) {
        score += 1200.0;
      }
      // Secondary fallback patterns for uncommon naming schemes
      else {
        final normalized = ParseTorrentTitle.normalizeTorrentTitle(rawPath).toLowerCase();
        final sStr = season.toString().padLeft(2, '0');
        final eStr = episode.toString().padLeft(2, '0');

        final fallbackRegexes = [
          RegExp('s0*$season[ ._x-]*e0*$episode', caseSensitive: false),
          RegExp('0*$season[xX]0*$episode', caseSensitive: false),
          RegExp('s0*$season[ ._x-]+0*$episode', caseSensitive: false),
          RegExp('(?:season|saison)[ ._x-]*0*$season.*(?:episode|ep|e)[ ._x-]*0*$episode', caseSensitive: false),
          RegExp(r'\b0*' '$season' r'[- ._]+0*' '$episode' r'\b'),
        ];

        bool matchedFallback = false;
        for (final p in fallbackRegexes) {
          if (p.hasMatch(normalized)) {
            matchedFallback = true;
            break;
          }
        }

        if (matchedFallback ||
            normalized.contains('s$sStr' 'e$eStr') ||
            normalized.contains('${season}x$eStr') ||
            normalized.contains('${sStr}x$eStr')) {
          score += 1100.0;
        }
      }
    }

    // 4. Episode Title Semantic Match (Extra confidence layer)
    if (episodeTitle != null && episodeTitle.trim().isNotEmpty) {
      final cleanEpTitle = episodeTitle
          .replaceAll(RegExp(r'[^\w\s]+'), '')
          .toLowerCase()
          .trim();
      final cleanPath = rawPath
          .replaceAll(RegExp(r'[^\w\s]+'), ' ')
          .toLowerCase();

      if (cleanEpTitle.length >= 4 && cleanPath.contains(cleanEpTitle)) {
        score += 600.0;
      }
    }

    // 5. Filename substring match for movies / general files
    if (filename != null && filename.trim().isNotEmpty) {
      final cleanName = filename.toLowerCase().trim();
      if (lowerPath.contains(cleanName)) {
        score += 300.0;
      }
    }

    return score;
  }

  /// Intelligently picks a matching media file (video or audio) from a torrent file list.
  static T? pickMediaFile<T>(
    List<T> files, {
    int? fileIndex,
    String? filename,
    int? season,
    int? episode,
    String? episodeTitle,
    required String Function(T) name,
    required int Function(T) size,
  }) {
    if (files.isEmpty) return null;

    // Filter to media files
    final mediaFiles = files.where((f) {
      final n = name(f).toLowerCase();
      final isMedia = _videoExts.any((ext) => n.endsWith(ext)) ||
          _audioExts.any((ext) => n.endsWith(ext));
      return isMedia;
    }).toList();

    final candidates = mediaFiles.isNotEmpty ? mediaFiles : files;

    // 1. Season & Episode match (Scored candidate ranking)
    if (season != null && episode != null) {
      // If explicit fileIndex is provided and matches, honor it
      if (fileIndex != null && fileIndex >= 0 && fileIndex < files.length) {
        final f = files[fileIndex];
        if (isFileMatch(name(f), season, episode, episodeTitle: episodeTitle)) {
          return f;
        }
      }

      // Rank all candidates by match score
      final scoredList = List<T>.from(candidates);
      scoredList.sort((a, b) {
        final scoreA = computeFileMatchScore(
          name(a),
          size(a),
          season: season,
          episode: episode,
          episodeTitle: episodeTitle,
          filename: filename,
        );
        final scoreB = computeFileMatchScore(
          name(b),
          size(b),
          season: season,
          episode: episode,
          episodeTitle: episodeTitle,
          filename: filename,
        );
        return scoreB.compareTo(scoreA);
      });

      final bestCandidate = scoredList.first;
      final bestScore = computeFileMatchScore(
        name(bestCandidate),
        size(bestCandidate),
        season: season,
        episode: episode,
        episodeTitle: episodeTitle,
        filename: filename,
      );

      if (bestScore > 0.0) {
        return bestCandidate;
      }
    }

    // 2. Explicit fileIndex provided and valid (when season/episode not specified)
    if (fileIndex != null && fileIndex >= 0 && fileIndex < files.length) {
      return files[fileIndex];
    }

    // 3. Match by exact or substring filename/title
    if (filename != null && filename.isNotEmpty) {
      final cleanName = filename.toLowerCase().trim();
      final nameMatches = candidates.where((f) {
        final fName = name(f).toLowerCase();
        final baseName = fName.split('/').last.split('\\').last;
        return fName.contains(cleanName) ||
            cleanName.contains(baseName) ||
            baseName.contains(cleanName);
      }).toList();

      if (nameMatches.isNotEmpty) {
        nameMatches.sort((a, b) => size(b).compareTo(size(a)));
        return nameMatches.first;
      }
    }

    // 4. Fallback: select largest media candidate
    final sorted = List<T>.from(candidates)
      ..sort((a, b) => size(b).compareTo(size(a)));
    return sorted.first;
  }
}
