import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../services/subtitles/subtitle_parser.dart';
import '../../services/subtitles/subtitle_sync_helper.dart';
import 'player_glass.dart';

/// Full-screen right-side floating drawer for dialogue speech following & subtitle sync.
class TextSyncOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final List<SubCue> initialCues;
  final double baseOffsetSec;
  final VoidCallback onClose;
  final Future<void> Function(List<SubCue> syncedCues, double offsetSec) onSave;

  const TextSyncOverlay({
    super.key,
    required this.controller,
    required this.initialCues,
    this.baseOffsetSec = 0.0,
    required this.onClose,
    required this.onSave,
  });

  @override
  State<TextSyncOverlay> createState() => _TextSyncOverlayState();
}

class _TextSyncOverlayState extends State<TextSyncOverlay> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<SyncPoint> _points = [];
  double _nudge = 0.0;
  List<SyncSegment> _segments = [];
  int? _rangeStart;
  int? _rangeEnd;
  bool _sectionMode = false;

  int? _selectedCueIndex;
  bool _isFollowing = true;
  bool _isProgrammaticScroll = false;
  String _searchQuery = '';
  List<int> _matchedIndices = [];
  int _currentMatchIndex = 0;
  GlobalKey _currentMatchKey = GlobalKey();
  GlobalKey _activeCueKey = GlobalKey();

  Timer? _positionUpdateTimer;
  Timer? _searchDebounceTimer;
  double _currentPositionSec = 0.0;
  bool _isPlaying = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nudge = widget.baseOffsetSec;
    _currentPositionSec = widget.controller.value.position.inMilliseconds / 1000.0;
    _isPlaying = widget.controller.value.isPlaying;

    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final posSec = widget.controller.value.position.inMilliseconds / 1000.0;
      final isPl = widget.controller.value.isPlaying;

      if ((posSec - _currentPositionSec).abs() > 0.05 || isPl != _isPlaying) {
        setState(() {
          _currentPositionSec = posSec;
          _isPlaying = isPl;
        });

        if (_isFollowing && _searchQuery.isEmpty) {
          _scrollToActiveCue();
        }
      }
    });

    _searchController.addListener(() {
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        final raw = _searchController.text.trim();
        final q = raw.toLowerCase();
        if (q != _searchQuery) {
          setState(() {
            _searchQuery = q;
            _currentMatchKey = GlobalKey();
            if (q.length >= 3) {
              _isFollowing = false;
              _matchedIndices = [];
              for (int i = 0; i < widget.initialCues.length; i++) {
                if (widget.initialCues[i].text.toLowerCase().contains(q)) {
                  _matchedIndices.add(i);
                }
              }
              _currentMatchIndex = 0;
            } else {
              _matchedIndices = [];
              _currentMatchIndex = 0;
            }
          });

          if (q.length >= 3 && _matchedIndices.isNotEmpty) {
            _scrollToMatch(_currentMatchIndex);
          }
        }
      });
    });

    // Auto-scroll immediately on mount to user's current dialogue position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveCue(immediate: true);
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) {
          _scrollToActiveCue(immediate: true);
        }
      });
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _scrollToActiveCue(immediate: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _positionUpdateTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double get _currentDelta {
    return SubtitleSyncHelper.computeDelta(_currentPositionSec, _points, _nudge);
  }

  double get _effectiveSubtitleTime {
    return _currentPositionSec - _currentDelta;
  }

  int? get _activeCueIndex {
    return SubtitleParser.findActiveCueIndex(widget.initialCues, _effectiveSubtitleTime);
  }

  int get _closestCueIndex {
    return SubtitleParser.findClosestCueIndex(widget.initialCues, _effectiveSubtitleTime);
  }

  void _scrollToActiveCue({bool immediate = false, int? targetIndex}) {
    if (!_scrollController.hasClients || widget.initialCues.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_activeCueKey.currentContext != null) {
        _isProgrammaticScroll = true;
        Scrollable.ensureVisible(
          _activeCueKey.currentContext!,
          alignment: 0.5,
          duration: immediate ? Duration.zero : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        ).then((_) {
          _isProgrammaticScroll = false;
        });
      }
    });
  }

  void _scrollToMatch(int matchIdx) {
    if (_matchedIndices.isEmpty || matchIdx < 0 || matchIdx >= _matchedIndices.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentMatchKey.currentContext != null) {
        _isProgrammaticScroll = true;
        Scrollable.ensureVisible(
          _currentMatchKey.currentContext!,
          alignment: 0.5,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        ).then((_) {
          _isProgrammaticScroll = false;
        });
      }
    });
  }

  void _goToNextMatch() {
    if (_matchedIndices.isEmpty) return;
    setState(() {
      _currentMatchKey = GlobalKey();
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchedIndices.length;
    });
    _scrollToMatch(_currentMatchIndex);
  }

  void _goToPrevMatch() {
    if (_matchedIndices.isEmpty) return;
    setState(() {
      _currentMatchKey = GlobalKey();
      _currentMatchIndex = (_currentMatchIndex - 1 + _matchedIndices.length) % _matchedIndices.length;
    });
    _scrollToMatch(_currentMatchIndex);
  }

  void _jumpToNow() {
    setState(() => _isFollowing = true);
    _scrollToActiveCue();
  }

  void _handleSyncFromHere(int cueIndex) {
    final cue = widget.initialCues[cueIndex];
    final playbackPos = _currentPositionSec;

    setState(() {
      if (_sectionMode && _rangeStart != null && _rangeEnd != null) {
        final lo = _rangeStart! < _rangeEnd! ? _rangeStart! : _rangeEnd!;
        final hi = _rangeStart! > _rangeEnd! ? _rangeStart! : _rangeEnd!;
        final curDelta = SubtitleSyncHelper.computeDelta(cue.start, _points, _nudge);
        final offset = (playbackPos - cue.start - curDelta);

        _segments = _segments.where((s) => !(s.startIdx == lo && s.endIdx == hi)).toList()
          ..add(SyncSegment(startIdx: lo, endIdx: hi, offsetSec: (offset * 1000).round() / 1000.0));

        _rangeStart = null;
        _rangeEnd = null;
        _selectedCueIndex = null;
        return;
      }

      final newPoint = SyncPoint(t: cue.start, at: playbackPos);
      if (_points.length < 2) {
        _points = [..._points, newPoint];
      } else {
        _points = [_points[0], newPoint];
      }
      _nudge = 0.0;
      _selectedCueIndex = null;
    });

    if (_isFollowing) {
      _scrollToActiveCue(targetIndex: cueIndex);
    }
  }

  void _handleSeekTo(int cueIndex) {
    final cue = widget.initialCues[cueIndex];
    final targetSec = cue.start + _currentDelta;
    final targetMs = (targetSec * 1000).round().clamp(0, widget.controller.value.duration.inMilliseconds);
    widget.controller.seekTo(Duration(milliseconds: targetMs));
  }

  void _handleNudge(double delta) {
    setState(() {
      _nudge = ((_nudge + delta) * 1000).round() / 1000.0;
    });

    if (_isFollowing) {
      _scrollToActiveCue();
    }
  }

  void _handleReset() {
    setState(() {
      _points = [];
      _nudge = 0.0;
      _segments = [];
      _rangeStart = null;
      _rangeEnd = null;
    });

    if (_isFollowing) {
      _scrollToActiveCue();
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final syncedCues = SubtitleSyncHelper.applyLinearSync(
        cues: widget.initialCues,
        points: _points,
        nudge: _nudge,
        segments: _segments,
      );

      final curDelta = SubtitleSyncHelper.computeDelta(0, _points, _nudge);
      await widget.onSave(syncedCues, curDelta);
      widget.onClose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving sync: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _isDirty =>
      _points.isNotEmpty ||
      (_nudge - widget.baseOffsetSec).abs() > 0.01 ||
      _segments.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cues = widget.initialCues;
    final activeIdx = _activeCueIndex;
    final closestIdx = _closestCueIndex;
    final currentDelta = _currentDelta;

    String hintText;
    if (_sectionMode) {
      hintText = 'Tap the first and last line of the section, then tap the line playing now and "Sync from here".';
    } else if (_points.isEmpty) {
      hintText = 'Find the line you hear right now, then tap "Sync from here". All subtitles shift to match.';
    } else if (_points.length == 1) {
      hintText = 'Point 1 set. If subtitles drift later on, play ahead and tap "Sync from here" at a later line to correct drift.';
    } else {
      hintText = 'Drift correction active (2 anchor points). Fine-tune with buttons, or fix a stray section.';
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: (480.0).clamp(280.0, MediaQuery.sizeOf(context).width * 0.92),
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xF2080C12),
            border: Border(
              left: BorderSide(color: PlayerTheme.edge),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xCC000000),
                blurRadius: 40,
                offset: Offset(-10, 0),
              ),
            ],
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SUBTITLE TIMING',
                            style: TextStyle(
                              color: PlayerTheme.inkSubtle,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _sectionMode ? 'Fix One Section' : 'Sync to Dialogue Speech',
                            style: const TextStyle(
                              color: PlayerTheme.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      PlayerIconButton(
                        size: 32,
                        iconSize: 16,
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close',
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),

                // Hint Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    hintText,
                    style: const TextStyle(
                      color: PlayerTheme.inkMuted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Search Bar with Search Navigation Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: PlayerTheme.raised,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _searchQuery.isNotEmpty && _matchedIndices.isNotEmpty
                            ? const Color(0xFFFFC107).withValues(alpha: 0.45)
                            : PlayerTheme.edge,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: _searchQuery.isNotEmpty && _matchedIndices.isNotEmpty
                              ? const Color(0xFFFFC107)
                              : PlayerTheme.inkSubtle,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: PlayerTheme.ink, fontSize: 13),
                            onSubmitted: (_) => _goToNextMatch(),
                            decoration: const InputDecoration(
                              hintText: 'Search dialogue words...',
                              hintStyle: TextStyle(color: PlayerTheme.inkSubtle, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchController.text.trim().isNotEmpty) ...[
                          // Match counter / hint pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _searchQuery.length >= 3 && _matchedIndices.isNotEmpty
                                  ? const Color(0x33FFC107)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _searchQuery.length < 3
                                  ? 'Type 3+ letters'
                                  : (_matchedIndices.isNotEmpty
                                      ? '${_currentMatchIndex + 1}/${_matchedIndices.length}'
                                      : '0/0'),
                              style: TextStyle(
                                color: _searchQuery.length >= 3 && _matchedIndices.isNotEmpty
                                    ? const Color(0xFFFFC107)
                                    : PlayerTheme.inkSubtle,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Previous match button
                          if (_searchQuery.length >= 3)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: _matchedIndices.isNotEmpty ? _goToPrevMatch : null,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 18,
                                  color: _matchedIndices.isNotEmpty
                                      ? PlayerTheme.ink
                                      : PlayerTheme.inkSubtle.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),

                          // Next match button
                          if (_searchQuery.length >= 3)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: _matchedIndices.isNotEmpty ? _goToNextMatch : null,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: _matchedIndices.isNotEmpty
                                      ? PlayerTheme.ink
                                      : PlayerTheme.inkSubtle.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),

                          // Clear button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                _searchController.clear();
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: PlayerTheme.inkSubtle,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Dialogue Cues List
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (!_isProgrammaticScroll && notification is ScrollUpdateNotification) {
                        if (_isFollowing) {
                          setState(() => _isFollowing = false);
                        }
                      }
                      return false;
                    },
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            top: 8,
                            bottom: MediaQuery.sizeOf(context).height * 0.65,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(cues.length, (index) {
                              final cue = cues[index];
                              final isActive = index == activeIdx || (activeIdx == null && index == closestIdx && _isFollowing);
                              final isSelected = _selectedCueIndex == index && !_sectionMode;

                              // Point anchor badges
                              int? pointNum;
                              for (int p = 0; p < _points.length; p++) {
                                if ((_points[p].t - cue.start).abs() < 0.01) {
                                  pointNum = p + 1;
                                  break;
                                }
                              }

                              // Section range check
                              final lo = _rangeStart != null && _rangeEnd != null
                                  ? (_rangeStart! < _rangeEnd! ? _rangeStart! : _rangeEnd!)
                                  : null;
                              final hi = _rangeStart != null && _rangeEnd != null
                                  ? (_rangeStart! > _rangeEnd! ? _rangeStart! : _rangeEnd!)
                                  : null;
                              final inRange = lo != null && hi != null && index >= lo && index <= hi;
                              final inSegment = _segments.any((s) => s.contains(index));

                              final isMatch = _searchQuery.length >= 3 &&
                                  cue.text.toLowerCase().contains(_searchQuery);
                              final isCurrentFocusedMatch = _searchQuery.length >= 3 &&
                                  _matchedIndices.isNotEmpty &&
                                  _currentMatchIndex < _matchedIndices.length &&
                                  _matchedIndices[_currentMatchIndex] == index;

                              Key? itemKey;
                              if (isCurrentFocusedMatch) {
                                itemKey = _currentMatchKey;
                              } else if (isActive && _searchQuery.isEmpty) {
                                itemKey = _activeCueKey;
                              } else {
                                itemKey = ValueKey('cue_$index');
                              }

                              return Column(
                                key: itemKey,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Material(
                                    color: isCurrentFocusedMatch
                                        ? const Color(0x59FFC107)
                                        : isMatch
                                            ? const Color(0x26FFC107)
                                            : isActive
                                                ? PlayerTheme.accent.withValues(alpha: 0.18)
                                                : inRange
                                                    ? PlayerTheme.accent.withValues(alpha: 0.1)
                                                    : Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        if (_sectionMode) {
                                          setState(() {
                                            if (_rangeStart == null || _rangeEnd != null) {
                                              _rangeStart = index;
                                              _rangeEnd = null;
                                            } else {
                                              _rangeEnd = index;
                                            }
                                          });
                                        } else {
                                          setState(() {
                                            _selectedCueIndex = isSelected ? null : index;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.white.withValues(alpha: 0.05),
                                            ),
                                            left: isCurrentFocusedMatch
                                                ? const BorderSide(
                                                    color: Color(0xFFFFC107),
                                                    width: 3.5,
                                                  )
                                                : isActive
                                                    ? const BorderSide(
                                                        color: PlayerTheme.accent,
                                                        width: 3.5,
                                                      )
                                                    : BorderSide.none,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Time label
                                            SizedBox(
                                              width: 48,
                                              child: Text(
                                                SubtitleParser.formatDisplayTime(cue.start),
                                                style: TextStyle(
                                                  color: isActive
                                                      ? PlayerTheme.accent
                                                      : PlayerTheme.inkSubtle,
                                                  fontSize: 11.5,
                                                  fontWeight: isActive
                                                      ? FontWeight.w700
                                                      : FontWeight.normal,
                                                  fontFeatures: const [
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Dialogue text
                                            Expanded(
                                              child: _buildHighlightedText(
                                                cue.text,
                                                _searchQuery,
                                                isActive,
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            // Right badge
                                            if (pointNum != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: PlayerTheme.accent,
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  'P$pointNum',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            else if (isActive)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: PlayerTheme.accent,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'NOW',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              )
                                            else if (inSegment)
                                              const Icon(
                                                Icons.check_rounded,
                                                color: PlayerTheme.accent,
                                                size: 16,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Expanded Action Box for Selected Line
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 8,
                                      ),
                                      color: PlayerTheme.raised,
                                      child: Row(
                                        children: [
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: PlayerTheme.accent,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: const Icon(Icons.check_rounded, size: 15),
                                            label: const Text(
                                              'Sync from here',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            onPressed: () => _handleSyncFromHere(index),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: PlayerTheme.inkMuted,
                                              side: const BorderSide(
                                                color: PlayerTheme.edgeSoft,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: const Icon(Icons.play_arrow_rounded, size: 15),
                                            label: const Text(
                                              'Jump here',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            onPressed: () => _handleSeekTo(index),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ),
                        ),

                        // Floating Jump to now button
                        if (!_isFollowing && _searchQuery.isEmpty)
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: PlayerTheme.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  shadowColor: Colors.black,
                                  elevation: 8,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                                label: const Text(
                                  'Jump to now',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _jumpToNow,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Fine Tuning & Sections Controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D121B),
                    border: Border(
                      top: BorderSide(color: PlayerTheme.edgeSoft),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _NudgeButton(label: '−0.1s', onTap: () => _handleNudge(-0.1)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: PlayerTheme.raised,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: PlayerTheme.edge),
                            ),
                            child: Text(
                              '${currentDelta >= 0 ? '+' : ''}${currentDelta.toStringAsFixed(2)}s',
                              style: const TextStyle(
                                color: PlayerTheme.ink,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _NudgeButton(label: '+0.1s', onTap: () => _handleNudge(0.1)),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: _sectionMode ? PlayerTheme.accent : PlayerTheme.inkMuted,
                          backgroundColor: _sectionMode
                              ? PlayerTheme.accent.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.content_cut_rounded, size: 14),
                        label: const Text('Fix section', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setState(() {
                            _sectionMode = !_sectionMode;
                            _rangeStart = null;
                            _rangeEnd = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Reset Button
                if (_isDirty)
                  Container(
                    color: const Color(0xFF0D121B),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: _handleReset,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.replay_rounded, size: 12, color: PlayerTheme.inkSubtle),
                            const SizedBox(width: 4),
                            Text(
                              _segments.isNotEmpty
                                  ? '${_segments.length} section fixes · Reset all'
                                  : 'Reset timing',
                              style: const TextStyle(color: PlayerTheme.inkSubtle, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Footer Play/Pause & Save
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF080C12),
                    border: Border(
                      top: BorderSide(color: PlayerTheme.edgeSoft),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: PlayerTheme.edgeSoft),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 18,
                          ),
                          label: Text(_isPlaying ? 'Pause' : 'Play'),
                          onPressed: () {
                            setState(() {
                              if (_isPlaying) {
                                widget.controller.pause();
                                _isPlaying = false;
                              } else {
                                widget.controller.play();
                                _isPlaying = true;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PlayerTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(_isSaving ? 'Saving...' : 'Save Timing'),
                          onPressed: _isSaving ? null : _handleSave,
                        ),
                      ),
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

  Widget _buildHighlightedText(String text, String query, bool isActive) {
    if (query.isEmpty || query.length < 3) {
      return Text(
        text,
        style: TextStyle(
          color: isActive ? PlayerTheme.ink : PlayerTheme.inkMuted,
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          height: 1.35,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(query, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Color(0xFFFFC107),
            color: Color(0xFF000000),
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: isActive ? PlayerTheme.ink : PlayerTheme.inkMuted,
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          height: 1.35,
        ),
        children: spans,
      ),
    );
  }
}

class _NudgeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NudgeButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: PlayerTheme.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
