import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/anime/anime_media.dart';
import '../../services/anime/anilist_service.dart';
import '../../services/anime/anime_library_service.dart';
import '../../widgets/common/performance_liquid_lens.dart';

class AnimeDetailsModal extends StatefulWidget {
  final AnimeMedia initialAnime;
  final Function(AnimeMedia anime, int episodeNumber, bool isDub) onPlayEpisode;
  final Function(AnimeMedia) onNavigateToAnime;
  final VoidCallback onClose;

  const AnimeDetailsModal({
    super.key,
    required this.initialAnime,
    required this.onPlayEpisode,
    required this.onNavigateToAnime,
    required this.onClose,
  });

  @override
  State<AnimeDetailsModal> createState() => _AnimeDetailsModalState();
}

class _AnimeDetailsModalState extends State<AnimeDetailsModal> {
  late AnimeMedia _anime;
  bool _isLoadingDetails = true;
  bool _isDub = false;
  int _selectedEpisodeBatch = 0; // 0: 1-25, 1: 26-50, etc.

  @override
  void initState() {
    super.initState();
    _anime = widget.initialAnime;
    _fetchFullDetails();
  }

  Future<void> _fetchFullDetails() async {
    final full = await AnilistService.instance.fetchAnimeDetails(_anime.id);
    if (full != null && mounted) {
      setState(() {
        _anime = full;
        _isLoadingDetails = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingDetails = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = AnimeLibraryService.instance;
    final watchItem = library.getWatchlistItem(_anime.id);
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 750;

    final modalWidth = isMobile ? size.width - 16 : math.min(size.width * 0.90, 880.0);
    final modalHeight = isMobile ? size.height * 0.92 : math.min(size.height * 0.90, 780.0);

    final totalEps = _anime.totalEpisodes > 0 ? _anime.totalEpisodes : 24;
    const batchSize = 30;
    final totalBatches = (totalEps / batchSize).ceil();

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            width: modalWidth,
            height: modalHeight,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0F18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Backdrop Header
                Stack(
                  children: [
                    SizedBox(
                      height: isMobile ? 180 : 230,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: _anime.backdropUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              const Color(0xFF0D0F18),
                            ],
                            stops: const [0.2, 1.0],
                          ),
                        ),
                      ),
                    ),

                    if (_isLoadingDetails)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          color: Color(0xFF7C5CFF),
                          backgroundColor: Colors.transparent,
                          minHeight: 2,
                        ),
                      ),

                    // Close Button
                    Positioned(
                      top: 14,
                      right: 14,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: widget.onClose,
                      ),
                    ),

                    // Title & Badges in Header
                    Positioned(
                      left: isMobile ? 16 : 24,
                      right: isMobile ? 60 : 80,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (_anime.averageScore > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB800),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.black,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _anime.formattedScore,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C5CFF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _anime.formattedFormat.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _anime.formattedStatus,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _anime.displayTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 20 : 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_anime.titleNative.isNotEmpty)
                            Text(
                              _anime.titleNative,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Scrollable Content
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 24,
                      vertical: 12,
                    ),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Action & Watchlist Row
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C5CFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () {
                              final epToPlay =
                                  watchItem?.lastWatchedEpisode ?? 1;
                              widget.onPlayEpisode(_anime, epToPlay, _isDub);
                            },
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                            label: Text(
                              watchItem != null &&
                                      watchItem.lastWatchedEpisode > 0
                                  ? 'Resume Ep ${watchItem.lastWatchedEpisode}'
                                  : 'Play Ep 1',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Watchlist Status Dropdown
                          PopupMenuButton<AnimeWatchStatus>(
                            onSelected: (status) {
                              library.setWatchlistStatus(_anime, status);
                            },
                            color: const Color(0xFF1B1E2B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: AnimeWatchStatus.watching,
                                child: Text(
                                  'Watching',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              const PopupMenuItem(
                                value: AnimeWatchStatus.planToWatch,
                                child: Text(
                                  'Plan to Watch',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              const PopupMenuItem(
                                value: AnimeWatchStatus.completed,
                                child: Text(
                                  'Completed',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              const PopupMenuItem(
                                value: AnimeWatchStatus.dropped,
                                child: Text(
                                  'Dropped',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: watchItem != null
                                      ? const Color(0xFF00D294)
                                      : Colors.white12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    watchItem != null
                                        ? Icons.check_circle_rounded
                                        : Icons.bookmark_outline_rounded,
                                    color: watchItem != null
                                        ? const Color(0xFF00D294)
                                        : Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    watchItem != null
                                        ? watchItem.status.name.toUpperCase()
                                        : 'ADD TO LIST',
                                    style: TextStyle(
                                      color: watchItem != null
                                          ? const Color(0xFF00D294)
                                          : Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Colors.white54,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),

                          // Sub / Dub Toggle Pill
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF151822),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _isDub = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !_isDub
                                          ? const Color(0xFF7C5CFF)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Text(
                                      'SUB',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _isDub = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isDub
                                          ? const Color(0xFF7C5CFF)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Text(
                                      'DUB',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Synopsis Section
                      if (_anime.description.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          _anime.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],

                      // Genres Chips
                      if (_anime.genres.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _anime.genres
                              .map(
                                (g) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Text(
                                    g,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 14),

                      // Episodes Header & Batch Selector
                      Row(
                        children: [
                          const Text(
                            'Episodes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '($totalEps total)',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),

                          if (totalBatches > 1)
                            Container(
                              height: 32,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B1E2B),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<int>(
                                value: _selectedEpisodeBatch,
                                underline: const SizedBox.shrink(),
                                dropdownColor: const Color(0xFF1B1E2B),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: Colors.white54,
                                ),
                                items: List.generate(
                                  totalBatches,
                                  (idx) {
                                    final start = idx * batchSize + 1;
                                    final end = math.min(
                                        (idx + 1) * batchSize, totalEps);
                                    return DropdownMenuItem(
                                      value: idx,
                                      child: Text('$start - $end'),
                                    );
                                  },
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(
                                        () => _selectedEpisodeBatch = val);
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Episode Grid
                      _buildEpisodeGrid(
                        totalEps,
                        _selectedEpisodeBatch * batchSize,
                        math.min(
                          (_selectedEpisodeBatch + 1) * batchSize,
                          totalEps,
                        ),
                        watchItem?.lastWatchedEpisode,
                      ),

                      // Characters & Voice Cast
                      if (_anime.characters.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const Text(
                          'Characters & Cast',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 140,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _anime.characters.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final char = _anime.characters[index];
                              return SizedBox(
                                width: 90,
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: char.imageLarge,
                                        width: 85,
                                        height: 85,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      char.nameFull,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      char.role,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 9,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Relations (Prequels / Sequels)
                      if (_anime.relations.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const Text(
                          'Franchise & Relations',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 160,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _anime.relations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final rel = _anime.relations[index];
                              return GestureDetector(
                                onTap: () async {
                                  final media = await AnilistService.instance
                                      .fetchAnimeDetails(rel.id);
                                  if (media != null) {
                                    widget.onNavigateToAnime(media);
                                  }
                                },
                                child: SizedBox(
                                  width: 100,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: CachedNetworkImage(
                                          imageUrl: rel.coverUrl,
                                          width: 100,
                                          height: 115,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        rel.relationType.replaceAll('_', ' '),
                                        style: const TextStyle(
                                          color: Color(0xFF7C5CFF),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        rel.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Recommendations
                      if (_anime.recommendations.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const Text(
                          'You May Also Like',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 170,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _anime.recommendations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final rec = _anime.recommendations[index];
                              return GestureDetector(
                                onTap: () => widget.onNavigateToAnime(rec),
                                child: SizedBox(
                                  width: 110,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: CachedNetworkImage(
                                          imageUrl: rec.coverUrl,
                                          width: 110,
                                          height: 130,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        rec.displayTitle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeGrid(
    int total,
    int startIndex,
    int endIndex,
    int? lastWatchedEp,
  ) {
    final count = endIndex - startIndex;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 80,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final epNum = startIndex + index + 1;
        final isWatched = lastWatchedEp != null && epNum <= lastWatchedEp;
        final isCurrent = lastWatchedEp == epNum;

        return GestureDetector(
          onTap: () => widget.onPlayEpisode(_anime, epNum, _isDub),
          child: Container(
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFF7C5CFF).withValues(alpha: 0.25)
                  : (isWatched
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFF151824)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCurrent
                    ? const Color(0xFF7C5CFF)
                    : (isWatched
                        ? Colors.white24
                        : Colors.white.withValues(alpha: 0.08)),
                width: isCurrent ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                '$epNum',
                style: TextStyle(
                  color: isCurrent
                      ? const Color(0xFF7C5CFF)
                      : (isWatched ? Colors.white70 : Colors.white),
                  fontSize: 14,
                  fontWeight:
                      isCurrent ? FontWeight.w900 : FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
