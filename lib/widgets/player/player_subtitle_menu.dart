import 'package:flutter/material.dart';
import 'package:playtorrio/models/subtitle/subtitle_model.dart';
import 'package:playtorrio/services/subtitles/subtitle_service.dart';
import 'player_glass.dart';

/// Full-featured subtitle selection, search, and timing menu.
class PlayerSubtitleMenu extends StatefulWidget {
  final List<SubtitleLanguageGroup> groups;
  final SubtitleVariant? selectedVariant;
  final bool isSubtitleEnabled;
  final String movieTitle;
  final String? imdbId;
  final int? season;
  final int? episode;
  final int? year;
  final double delaySec;
  final ValueChanged<SubtitleVariant?> onSelectVariant;
  final VoidCallback onToggleOff;
  final VoidCallback onOpenSyncBar;
  final VoidCallback onOpenStyleBar;
  final VoidCallback onOpenTextSync;
  final VoidCallback onClose;

  const PlayerSubtitleMenu({
    super.key,
    required this.groups,
    this.selectedVariant,
    required this.isSubtitleEnabled,
    required this.movieTitle,
    this.imdbId,
    this.season,
    this.episode,
    this.year,
    required this.delaySec,
    required this.onSelectVariant,
    required this.onToggleOff,
    required this.onOpenSyncBar,
    required this.onOpenStyleBar,
    required this.onOpenTextSync,
    required this.onClose,
  });

  @override
  State<PlayerSubtitleMenu> createState() => _PlayerSubtitleMenuState();
}

class _PlayerSubtitleMenuState extends State<PlayerSubtitleMenu> {
  String? _selectedLanguage;
  String _sourceFilter = 'all'; // 'all', 'embedded', 'external'
  bool _filterHI = false;
  bool _filterForced = false;
  List<SubtitleLanguageGroup> _dynamicGroups = [];
  bool _isLoadingSearch = false;
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _dynamicGroups = List.from(widget.groups);
    if (_dynamicGroups.isNotEmpty) {
      if (widget.selectedVariant != null) {
        _selectedLanguage = widget.selectedVariant!.language;
      } else {
        _selectedLanguage = _dynamicGroups.first.language;
      }
    }
  }

  Future<void> _searchOnline() async {
    setState(() => _isLoadingSearch = true);
    try {
      final results = await SubtitleService().fetchAllSubtitles(
        _searchQuery?.isNotEmpty == true ? _searchQuery! : widget.movieTitle,
        imdbId: widget.imdbId,
        season: widget.season,
        episode: widget.episode,
        year: widget.year,
      );
      setState(() {
        _dynamicGroups = results;
        if (_dynamicGroups.isNotEmpty && _selectedLanguage == null) {
          _selectedLanguage = _dynamicGroups.first.language;
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingSearch = false);
    }
  }

  String _getLanguageEmoji(String lang) {
    final l = lang.toLowerCase();
    if (l.contains('en') || l.contains('eng')) return '🇺🇸';
    if (l.contains('ar') || l.contains('ara')) return '🇸🇦';
    if (l.contains('es') || l.contains('spa')) return '🇪🇸';
    if (l.contains('fr') || l.contains('fre')) return '🇫🇷';
    if (l.contains('de') || l.contains('ger')) return '🇩🇪';
    if (l.contains('it') || l.contains('ita')) return '🇮🇹';
    if (l.contains('pt') || l.contains('por')) return '🇧🇷';
    if (l.contains('ru') || l.contains('rus')) return '🇷🇺';
    if (l.contains('ja') || l.contains('jpn')) return '🇯🇵';
    if (l.contains('ko') || l.contains('kor')) return '🇰🇷';
    if (l.contains('zh') || l.contains('chi')) return '🇨🇳';
    if (l.contains('hi') || l.contains('hin')) return '🇮🇳';
    if (l.contains('tr') || l.contains('tur')) return '🇹🇷';
    return '🌐';
  }

  List<SubtitleVariant> _getFilteredVariants() {
    List<SubtitleVariant> all = [];
    if (_selectedLanguage == '__all__' || _selectedLanguage == null) {
      all = _dynamicGroups.expand((g) => g.variants).toList();
    } else {
      final g = _dynamicGroups.firstWhere(
        (group) => group.language == _selectedLanguage,
        orElse: () => SubtitleLanguageGroup(language: '', variants: []),
      );
      all = g.variants;
    }

    return all.filter((v) {
      if (_filterHI && !(v.title.contains('[CC]') || v.title.contains('SDH') || v.title.contains('HI'))) {
        return false;
      }
      if (_filterForced && !v.title.toLowerCase().contains('forced')) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalVariantsCount = _dynamicGroups.fold<int>(0, (sum, g) => sum + g.variants.length);
    final isOff = !widget.isSubtitleEnabled || widget.selectedVariant == null;
    final filteredVariants = _getFilteredVariants();
    final screen = MediaQuery.sizeOf(context);

    return PlayerGlassCard(
      width: (520.0).clamp(280.0, screen.width - 32),
      height: (420.0).clamp(260.0, screen.height - 110),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PlayerTheme.edgeSoft)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Subtitles',
                      style: TextStyle(
                        color: PlayerTheme.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (totalVariantsCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: PlayerTheme.raised,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$totalVariantsCount',
                          style: const TextStyle(
                            color: PlayerTheme.inkSubtle,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Header Action Icons
                Row(
                  children: [
                    // Subtitle Delay Bar
                    PlayerIconButton(
                      size: 34,
                      iconSize: 17,
                      icon: const Icon(Icons.timer_outlined),
                      tooltip: 'Subtitle Sync Bar',
                      showActiveBadge: widget.delaySec != 0,
                      onPressed: () {
                        widget.onClose();
                        widget.onOpenSyncBar();
                      },
                    ),
                    const SizedBox(width: 4),

                    // Subtitle Appearance Style Bar
                    PlayerIconButton(
                      size: 34,
                      iconSize: 17,
                      icon: const Icon(Icons.tune_rounded),
                      tooltip: 'Subtitle Appearance',
                      onPressed: () {
                        widget.onClose();
                        widget.onOpenStyleBar();
                      },
                    ),
                    const SizedBox(width: 4),

                    // Text Sync to Speech
                    PlayerIconButton(
                      size: 34,
                      iconSize: 17,
                      icon: const Icon(Icons.text_fields_rounded),
                      tooltip: 'Speech Text Sync',
                      onPressed: () {
                        widget.onClose();
                        widget.onOpenTextSync();
                      },
                    ),
                    const SizedBox(width: 8),

                    // Close Button
                    PlayerIconButton(
                      size: 34,
                      iconSize: 16,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Two-Panel Body
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Language Sidebar
                Container(
                  width: 140,
                  decoration: const BoxDecoration(
                    color: Color(0x22000000),
                    border: Border(right: BorderSide(color: PlayerTheme.edgeSoft)),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      // Subtitles Off Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            widget.onToggleOff();
                            widget.onClose();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isOff ? PlayerTheme.raised : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isOff ? PlayerTheme.edge : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: isOff ? PlayerTheme.accent : PlayerTheme.raised,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: isOff
                                      ? const Icon(Icons.check_rounded, size: 10, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Off',
                                  style: TextStyle(
                                    color: PlayerTheme.inkMuted,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (_dynamicGroups.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 8, top: 12, bottom: 4),
                          child: Text(
                            'LANGUAGES',
                            style: TextStyle(
                              color: PlayerTheme.inkSubtle,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),

                        // All Languages Option
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _selectedLanguage = '__all__'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: _selectedLanguage == '__all__' ? PlayerTheme.raised : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedLanguage == '__all__' ? PlayerTheme.edge : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Text('🌐', style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'All Languages',
                                      style: TextStyle(
                                        color: PlayerTheme.inkMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$totalVariantsCount',
                                    style: const TextStyle(
                                      color: PlayerTheme.inkSubtle,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Individual Language Groups
                        ..._dynamicGroups.map((g) {
                          final isSelected = _selectedLanguage == g.language;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setState(() => _selectedLanguage = g.language),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                margin: const EdgeInsets.only(bottom: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? PlayerTheme.raised : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? PlayerTheme.edge : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(_getLanguageEmoji(g.language), style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        g.language,
                                        style: TextStyle(
                                          color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${g.variants.length}',
                                      style: const TextStyle(
                                        color: PlayerTheme.inkSubtle,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),

                // Right Variants & Search Panel
                Expanded(
                  child: Column(
                    children: [
                      // Filter Chips Toolbar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: PlayerTheme.edgeSoft)),
                        ),
                        child: Row(
                          children: [
                            PlayerToggleChip(
                              active: _sourceFilter == 'all',
                              label: 'All',
                              onClick: () => setState(() => _sourceFilter = 'all'),
                            ),
                            const SizedBox(width: 6),
                            PlayerToggleChip(
                              active: _filterHI,
                              label: 'HI / CC',
                              onClick: () => setState(() => _filterHI = !_filterHI),
                            ),
                            const SizedBox(width: 6),
                            PlayerToggleChip(
                              active: _filterForced,
                              label: 'Forced',
                              onClick: () => setState(() => _filterForced = !_filterForced),
                            ),
                          ],
                        ),
                      ),

                      // Subtitles List
                      Expanded(
                        child: _isLoadingSearch
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: PlayerTheme.accent,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : filteredVariants.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.subtitles_off_rounded,
                                          size: 32,
                                          color: PlayerTheme.inkSubtle,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'No subtitles available.',
                                          style: TextStyle(
                                            color: PlayerTheme.inkMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: PlayerTheme.accent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(Icons.search_rounded, size: 16),
                                          label: const Text('Search Online Providers', style: TextStyle(fontSize: 12)),
                                          onPressed: _searchOnline,
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(8),
                                    itemCount: filteredVariants.length,
                                    itemBuilder: (context, i) {
                                      final variant = filteredVariants[i];
                                      final isSelected = widget.selectedVariant?.downloadUrl == variant.downloadUrl;

                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: () {
                                            widget.onSelectVariant(variant);
                                            widget.onClose();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            margin: const EdgeInsets.only(bottom: 4),
                                            decoration: BoxDecoration(
                                              color: isSelected ? PlayerTheme.raised : Colors.transparent,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSelected ? PlayerTheme.edge : Colors.transparent,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 18,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? PlayerTheme.accent : PlayerTheme.raised,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: isSelected
                                                      ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                                                      : null,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        variant.title,
                                                        style: TextStyle(
                                                          color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                                                          fontSize: 12.5,
                                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: PlayerTheme.raised,
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              variant.providerName.toUpperCase(),
                                                              style: const TextStyle(
                                                                color: PlayerTheme.inkSubtle,
                                                                fontSize: 9.5,
                                                                fontWeight: FontWeight.w700,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            variant.format.toUpperCase(),
                                                            style: const TextStyle(
                                                              color: PlayerTheme.inkSubtle,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),

                      // Bottom Search Trigger
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: PlayerTheme.edgeSoft)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: _searchOnline,
                              child: const MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Row(
                                  children: [
                                    Icon(Icons.search_rounded, size: 14, color: PlayerTheme.accent),
                                    SizedBox(width: 6),
                                    Text(
                                      'Find more subtitles',
                                      style: TextStyle(
                                        color: PlayerTheme.inkMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  Iterable<T> filter(bool Function(T element) test) sync* {
    for (final element in this) {
      if (test(element)) yield element;
    }
  }
}
