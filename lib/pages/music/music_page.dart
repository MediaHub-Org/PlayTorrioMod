import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../models/music/music_track.dart';
import '../../services/music/music_service.dart';
import '../../services/music/music_player_controller.dart';
import '../../services/music/octave_library_service.dart';
import '../../services/glass_settings.dart';
import '../../widgets/common/custom_scroll_track.dart';
import '../../widgets/common/performance_liquid_lens.dart';
import '../../widgets/common/section_header.dart';
import '../settings/settings_page.dart';
import '../../utils/route_transitions.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final OctaveMusicService _musicService = OctaveMusicService.instance;
  final MusicPlayerController _playerController =
      MusicPlayerController.instance;
  final OctaveLibraryService _libraryService = OctaveLibraryService.instance;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  String _activeTab =
      'Home'; // 'Home', 'Search', 'Browse', 'Radio', 'Podcasts', 'Library'

  Map<String, List<MusicTrack>> _sections = {};
  List<MusicArtist> _trendingArtists = [];
  MusicTrack? _heroTrack;
  OctaveSearchData _searchData = const OctaveSearchData(
    tracks: [],
    artists: [],
    albums: [],
  );
  OctaveArtistDetails? _activeArtistModal;
  UserPlaylist? _activePlaylistModal;

  bool _isLoading = true;
  bool _isSearching = false;
  bool _hasSearched = false;
  String _activeQuery = '';
  String _selectedFilter = 'All';
  Timer? _debounceTimer;

  bool _isPlayerExpanded = false;
  bool _showQueueDrawer = false;
  bool _showLyricsDrawer = false;
  bool _showShortcutsModal = false;
  String? _toastMessage;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _playerController.addListener(_onStateChanged);
    _libraryService.addListener(_onStateChanged);
    _libraryService.init();
    _loadMusicData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _toastTimer?.cancel();
    _playerController.removeListener(_onStateChanged);
    _libraryService.removeListener(_onStateChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  Future<void> _loadMusicData() async {
    setState(() => _isLoading = true);
    final sections = await _musicService.fetchFeaturedSections();
    final artists = await _musicService.fetchTrendingArtists();

    MusicTrack? hero;
    if (sections.isNotEmpty && sections.values.first.isNotEmpty) {
      hero = sections.values.first.first;
    }

    if (mounted) {
      setState(() {
        _sections = sections;
        _trendingArtists = artists;
        _heroTrack = hero;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _hasSearched = false;
        _searchData = const OctaveSearchData(
          tracks: [],
          artists: [],
          albums: [],
        );
        _activeQuery = '';
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() {
        _isSearching = true;
        _activeQuery = query.trim();
        if (_activeTab != 'Search') _activeTab = 'Search';
      });

      final results = await _musicService.searchFull(query.trim());

      if (mounted) {
        setState(() {
          _searchData = results;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    });
  }

  void _onGenreTap(String query) {
    _searchController.text = query;
    _onSearchChanged(query);
  }

  Future<void> _openArtistModal(String artistId) async {
    final details = await _musicService.fetchArtistDetails(artistId);
    if (details != null && mounted) {
      setState(() {
        _activeArtistModal = details;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_searchFocusNode.hasFocus)
      return; // Don't intercept while typing in search

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      _playerController.togglePlayPause();
    } else if (key == LogicalKeyboardKey.keyJ) {
      final newPos = _playerController.position - const Duration(seconds: 5);
      _playerController.seekTo(newPos.inSeconds < 0 ? Duration.zero : newPos);
      _showToast('Seek -5s');
    } else if (key == LogicalKeyboardKey.keyL) {
      final newPos = _playerController.position + const Duration(seconds: 5);
      _playerController.seekTo(newPos);
      _showToast('Seek +5s');
    } else if (key == LogicalKeyboardKey.keyM) {
      _playerController.setVolume(_playerController.volume > 0 ? 0.0 : 1.0);
      _showToast(_playerController.volume == 0 ? 'Muted' : 'Unmuted');
    } else if (key == LogicalKeyboardKey.keyQ) {
      setState(() => _showQueueDrawer = !_showQueueDrawer);
    } else if (key == LogicalKeyboardKey.keyF) {
      setState(() => _isPlayerExpanded = !_isPlayerExpanded);
    } else if (key == LogicalKeyboardKey.slash ||
        (HardwareKeyboard.instance.isShiftPressed &&
            key == LogicalKeyboardKey.slash)) {
      setState(() => _showShortcutsModal = !_showShortcutsModal);
    }
  }

  void _showCreatePlaylistDialog({MusicTrack? initialTrack}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13151C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: const Color(0xFF7C5CFF).withValues(alpha: 0.3),
          ),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.playlist_add_rounded,
              color: Color(0xFF7C5CFF),
              size: 26,
            ),
            SizedBox(width: 10),
            Text(
              'New Playlist',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (initialTrack != null) ...[
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: initialTrack.coverUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          initialTrack.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          initialTrack.artist,
                          style: const TextStyle(
                            color: Colors.white54,
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
              const SizedBox(height: 16),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter playlist title...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1B1E2B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7C5CFF)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C5CFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final pl = await _libraryService.createPlaylist(name);
                if (initialTrack != null) {
                  await _libraryService.addTrackToPlaylist(pl.id, initialTrack);
                  _showToast('Added "${initialTrack.title}" to "$name"');
                } else {
                  _showToast('Created playlist "$name"');
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text(
              'Create',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistMenu(MusicTrack track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final playlists = _libraryService.userPlaylists;
        return PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: track.coverUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            style: const TextStyle(
                              color: Color(0xFF9E9EA8),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Save to Playlist',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showCreatePlaylistDialog(initialTrack: track);
                      },
                      icon: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF7C5CFF),
                        size: 18,
                      ),
                      label: const Text(
                        'New Playlist',
                        style: TextStyle(
                          color: Color(0xFF7C5CFF),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.playlist_add_rounded,
                            color: Colors.white38,
                            size: 40,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No custom playlists yet',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C5CFF),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showCreatePlaylistDialog(initialTrack: track);
                            },
                            child: const Text(
                              'Create First Playlist',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final pl = playlists[index];
                        final inPlaylist = pl.tracks.any(
                          (t) => t.id == track.id,
                        );

                        return PerformanceLiquidLens(
                          style: PerformanceGlassStyles.menuButton,
                          child: InkWell(
                            onTap: () async {
                              if (inPlaylist) {
                                await _libraryService.removeTrackFromPlaylist(
                                  pl.id,
                                  track.id,
                                );
                                _showToast('Removed from "${pl.title}"');
                              } else {
                                await _libraryService.addTrackToPlaylist(
                                  pl.id,
                                  track,
                                );
                                _showToast('Added to "${pl.title}"');
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161924),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: inPlaylist
                                      ? const Color(0xFF7C5CFF)
                                      : Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF7C5CFF,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.playlist_play_rounded,
                                      color: Color(0xFF7C5CFF),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pl.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${pl.tracks.length} songs',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    inPlaylist
                                        ? Icons.check_circle_rounded
                                        : Icons.add_circle_outline_rounded,
                                    color: inPlaylist
                                        ? const Color(0xFF7C5CFF)
                                        : Colors.white54,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToSettings(Offset? tapPosition) {
    Navigator.push(
      context,
      LiquidRevealRoute(page: const SettingsPage(), tapPosition: tapPosition),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context).width;
    final isDesktop = screenSize >= 900;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final backgroundContent = Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF08090C))),

        Row(
          children: [
            if (isDesktop)
              _OctaveSidebar(
                activeTab: _activeTab,
                onTabSelected: (tab) {
                  setState(() {
                    _activeTab = tab;
                    if (tab != 'Search') _clearSearch();
                  });
                },
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: _buildMainBodyContent(isDesktop),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _OctaveTopHeader(
                      searchController: _searchController,
                      searchFocusNode: _searchFocusNode,
                      onSearchChanged: _onSearchChanged,
                      onClearSearch: _clearSearch,
                      onSettingsTap: _navigateToSettings,
                      onShortcutsTap: () =>
                          setState(() => _showShortcutsModal = true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    final overlayChildren = <Widget>[
      if (isDesktop)
        Positioned(
          right: 20,
          bottom: _playerController.hasTrack ? 100 : 30,
          child: CustomScrollTrack(controller: _scrollController),
        ),

      if (!isDesktop)
        Positioned(
          bottom: _playerController.hasTrack ? 84 : bottomPadding,
          left: 0,
          right: 0,
          child: _OctaveMobileBottomNav(
            activeTab: _activeTab,
            onTabSelected: (tab) {
              setState(() {
                _activeTab = tab;
                if (tab != 'Search') _clearSearch();
              });
            },
          ),
        ),

      if (_playerController.hasTrack)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _OctaveBottomPlayerBar(
            isFavorite:
                _playerController.currentTrack != null &&
                _libraryService.isTrackLiked(
                  _playerController.currentTrack!.id,
                ),
            showQueue: _showQueueDrawer,
            showLyrics: _showLyricsDrawer,
            onFavoriteToggle: () {
              if (_playerController.currentTrack != null) {
                _libraryService.toggleLikeTrack(
                  _playerController.currentTrack!,
                );
                _showToast(
                  _libraryService.isTrackLiked(
                        _playerController.currentTrack!.id,
                      )
                      ? 'Saved to Library'
                      : 'Removed from Library',
                );
              }
            },
            onQueueToggle: () => setState(() {
              _showQueueDrawer = !_showQueueDrawer;
              if (_showQueueDrawer) _showLyricsDrawer = false;
            }),
            onLyricsToggle: () => setState(() {
              _showLyricsDrawer = !_showLyricsDrawer;
              if (_showLyricsDrawer) _showQueueDrawer = false;
            }),
            onExpand: () => setState(() => _isPlayerExpanded = true),
          ),
        ),

      if (_showQueueDrawer)
        Positioned(
          top: 75,
          right: 0,
          bottom: 84,
          child: _OctaveQueueDrawer(
            onClose: () => setState(() => _showQueueDrawer = false),
          ),
        ),

      if (_showLyricsDrawer && _playerController.hasTrack)
        Positioned(
          top: 75,
          right: 0,
          bottom: 84,
          child: _OctaveLyricsDrawer(
            track: _playerController.currentTrack!,
            onClose: () => setState(() => _showLyricsDrawer = false),
          ),
        ),

      if (_activeArtistModal != null)
        Positioned.fill(
          child: _OctaveArtistDetailModal(
            details: _activeArtistModal!,
            onClose: () => setState(() => _activeArtistModal = null),
            onPlayTrack: (track, playlist) =>
                _playerController.playTrack(track, playlistQueue: playlist),
            onAddToPlaylist: _showAddToPlaylistMenu,
          ),
        ),

      if (_activePlaylistModal != null)
        Positioned.fill(
          child: _OctavePlaylistDetailModal(
            playlist: _activePlaylistModal!,
            onClose: () => setState(() => _activePlaylistModal = null),
            onPlayTrack: (track, playlist) =>
                _playerController.playTrack(track, playlistQueue: playlist),
          ),
        ),

      if (_showShortcutsModal)
        Positioned.fill(
          child: _OctaveShortcutsModal(
            onClose: () => setState(() => _showShortcutsModal = false),
          ),
        ),

      if (_toastMessage != null)
        Positioned(
          bottom: _playerController.hasTrack ? 100 : 30,
          left: 0,
          right: 0,
          child: Center(
            child: PerformanceLiquidLens(
              style: PerformanceGlassStyles.menu,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF13151C).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF7C5CFF).withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C5CFF).withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF7C5CFF),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _toastMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

      if (_playerController.hasTrack)
        Positioned.fill(
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            offset: _isPlayerExpanded ? Offset.zero : const Offset(0, 1),
            child: _OctaveExpandedPlayer(
              onDismiss: () => setState(() => _isPlayerExpanded = false),
            ),
          ),
        ),
    ];

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF08090C),
        body: ValueListenableBuilder<bool>(
          valueListenable: GlassSettings.enabled,
          builder: (context, enabled, _) {
            final overlays = Stack(children: overlayChildren);
            if (enabled) {
              return LiquidGlassView(
                realTimeCapture: true,
                useSync: true,
                pixelRatio: 0.85,
                refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
                regionCapture: true,
                backgroundWidget: backgroundContent,
                child: overlays,
              );
            }

            return Container(
              color: const Color(0xFF08090C),
              child: Stack(
                children: [
                  RepaintBoundary(child: backgroundContent),
                  ...overlayChildren,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainBodyContent(bool isDesktop) {
    if (_isLoading && _sections.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
      );
    }

    if (_activeTab == 'Search' ||
        _hasSearched ||
        _searchController.text.isNotEmpty) {
      return _buildSearchView();
    }
    if (_activeTab == 'Browse') return _buildBrowseView();
    if (_activeTab == 'Radio') return _buildRadioView();
    if (_activeTab == 'Podcasts') return _buildPodcastsView();
    if (_activeTab == 'Library') return _buildLibraryView();

    final bottomPad = isDesktop ? 120.0 : 160.0;

    return RefreshIndicator(
      color: const Color(0xFF7C5CFF),
      backgroundColor: const Color(0xFF151822),
      onRefresh: _loadMusicData,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.only(top: 75, bottom: bottomPad),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          if (_heroTrack != null)
            _OctaveHeroBillboard(
              track: _heroTrack!,
              onPlayTap: () => _playerController.playTrack(_heroTrack!),
              onSaveTap: () {
                _libraryService.toggleLikeTrack(_heroTrack!);
                _showToast(
                  _libraryService.isTrackLiked(_heroTrack!.id)
                      ? 'Saved to Library'
                      : 'Removed from Library',
                );
              },
              onAddToPlaylistTap: () => _showAddToPlaylistMenu(_heroTrack!),
              isSaved: _libraryService.isTrackLiked(_heroTrack!.id),
            ),
          const SizedBox(height: 24),
          if (_trendingArtists.isNotEmpty)
            _OctaveTrendingArtists(
              artists: _trendingArtists,
              onArtistTap: (artist) {
                if (artist.id.isNotEmpty)
                  _openArtistModal(artist.id);
                else
                  _onGenreTap(artist.name);
              },
            ),
          for (final entry in _sections.entries)
            _OctaveCategorySlider(
              title: entry.key,
              tracks: entry.value,
              onAddToPlaylist: _showAddToPlaylistMenu,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchView() {
    final sizing = _OctaveCardSizing.fromWidth(
      MediaQuery.sizeOf(context).width,
    );

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 150),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _filterTab('All'),
              const SizedBox(width: 8),
              _filterTab('Tracks (${_searchData.tracks.length})'),
              const SizedBox(width: 8),
              _filterTab('Artists (${_searchData.artists.length})'),
              const SizedBox(width: 8),
              _filterTab('Albums (${_searchData.albums.length})'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48.0),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
            ),
          )
        else if (_searchData.tracks.isEmpty && _searchData.artists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    color: Colors.white38,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results for "$_activeQuery"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          if ((_selectedFilter == 'All' ||
                  _selectedFilter.startsWith('Tracks')) &&
              _searchData.tracks.isNotEmpty) ...[
            const Text(
              'Songs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchData.tracks.length.clamp(0, 10),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final track = _searchData.tracks[index];
                return _OctaveTrackRow(
                  track: track,
                  isPlaying:
                      _playerController.currentTrack?.id == track.id &&
                      _playerController.isPlaying,
                  isCurrent: _playerController.currentTrack?.id == track.id,
                  onTap: () => _playerController.playTrack(
                    track,
                    playlistQueue: _searchData.tracks,
                  ),
                  onMoreTap: () => _showAddToPlaylistMenu(track),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
          if ((_selectedFilter == 'All' ||
                  _selectedFilter.startsWith('Albums')) &&
              _searchData.albums.isNotEmpty) ...[
            const Text(
              'Albums',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    (MediaQuery.sizeOf(context).width / sizing.cardWidth)
                        .floor()
                        .clamp(2, 6),
                mainAxisSpacing: 20,
                crossAxisSpacing: 16,
                childAspectRatio: sizing.cardWidth / sizing.totalHeight,
              ),
              itemCount: _searchData.albums.length.clamp(0, 12),
              itemBuilder: (context, index) {
                final album = _searchData.albums[index];
                return _OctaveAlbumCard(
                  album: album,
                  onTap: () => _onGenreTap(album.title),
                );
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildBrowseView() {
    final genres = [
      {
        'title': 'Pop Hits',
        'color': const Color(0xFF7C5CFF),
        'query': 'Pop Hits',
      },
      {
        'title': 'Hip-Hop',
        'color': const Color(0xFF7850FF),
        'query': 'Hip-Hop',
      },
      {
        'title': 'Chill Lofi',
        'color': const Color(0xFF00D294),
        'query': 'Chill Lofi',
      },
      {
        'title': 'Workout',
        'color': const Color(0xFFFF6568),
        'query': 'Workout',
      },
      {
        'title': 'Focus Piano',
        'color': const Color(0xFF625FFF),
        'query': 'Focus Piano',
      },
      {
        'title': 'Rock Essentials',
        'color': const Color(0xFFF99C00),
        'query': 'Rock Essentials',
      },
      {
        'title': '80s Throwbacks',
        'color': const Color(0xFFE12AFB),
        'query': '80s Hits',
      },
      {
        'title': 'Soundtracks',
        'color': const Color(0xFF00D2EF),
        'query': 'Hans Zimmer',
      },
    ];

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 150),
      children: [
        const Text(
          'Browse Moods & Genres',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
          ),
          itemCount: genres.length,
          itemBuilder: (context, index) {
            final g = genres[index];
            final color = g['color'] as Color;
            return GestureDetector(
              onTap: () => _onGenreTap(g['query'] as String),
              child: PerformanceLiquidLens(
                style: PerformanceGlassStyles.menu,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.85),
                        color.withValues(alpha: 0.40),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      g['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRadioView() {
    final radioGenres = [
      {'name': 'Pop Radio', 'color': const Color(0xFF7C5CFF)},
      {'name': 'Rap/Hip Hop', 'color': const Color(0xFF7850FF)},
      {'name': 'Rock Mix', 'color': const Color(0xFFF99C00)},
      {'name': 'Dance & Electro', 'color': const Color(0xFF00D294)},
      {'name': 'R&B Station', 'color': const Color(0xFFE12AFB)},
      {'name': 'Alternative', 'color': const Color(0xFF625FFF)},
      {'name': 'Folk & Country', 'color': const Color(0xFFFAC800)},
      {'name': 'Reggae Vibes', 'color': const Color(0xFF05DF72)},
      {'name': 'Jazz & Blues', 'color': const Color(0xFF00D2EF)},
      {'name': 'Classical Radio', 'color': const Color(0xFFC7D2FF)},
      {'name': 'Films & Games', 'color': const Color(0xFFFF667F)},
      {'name': 'Heavy Metal', 'color': const Color(0xFFFB2C36)},
    ];

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 150),
      children: [
        const Text(
          'Radio Stations & Mixes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Non-stop music channels tuned to your mood.',
          style: TextStyle(color: Color(0xFF9E9EA8), fontSize: 14),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: radioGenres.length,
          itemBuilder: (context, index) {
            final station = radioGenres[index];
            final color = station['color'] as Color;
            return GestureDetector(
              onTap: () => _onGenreTap(station['name'] as String),
              child: PerformanceLiquidLens(
                style: PerformanceGlassStyles.menu,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: color.withValues(alpha: 0.20),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.radio_rounded, color: color, size: 28),
                      Text(
                        station['name'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPodcastsView() {
    final podcastCategories = [
      {
        'title': 'True Crime',
        'icon': Icons.fingerprint_rounded,
        'color': const Color(0xFFFB2C36),
      },
      {
        'title': 'Comedy & Humor',
        'icon': Icons.sentiment_very_satisfied_rounded,
        'color': const Color(0xFFFAC800),
      },
      {
        'title': 'Society & Culture',
        'icon': Icons.public_rounded,
        'color': const Color(0xFF625FFF),
      },
      {
        'title': 'History & Stories',
        'icon': Icons.auto_stories_rounded,
        'color': const Color(0xFF00D294),
      },
      {
        'title': 'News & Politics',
        'icon': Icons.newspaper_rounded,
        'color': const Color(0xFF00D2EF),
      },
      {
        'title': 'Science & Tech',
        'icon': Icons.memory_rounded,
        'color': const Color(0xFFE12AFB),
      },
    ];

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 150),
      children: [
        const Text(
          'Podcasts & Shows',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Explore thousands of original podcasts and talk shows.',
          style: TextStyle(color: Color(0xFF9E9EA8), fontSize: 14),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: podcastCategories.length,
          itemBuilder: (context, index) {
            final cat = podcastCategories[index];
            final color = cat['color'] as Color;
            return GestureDetector(
              onTap: () => _onGenreTap(cat['title'] as String),
              child: PerformanceLiquidLens(
                style: PerformanceGlassStyles.menu,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFF13151C).withValues(alpha: 0.8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(cat['icon'] as IconData, color: color, size: 28),
                      Text(
                        cat['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLibraryView() {
    final liked = _libraryService.likedTracks;
    final playlists = _libraryService.userPlaylists;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 150),
      children: [
        Row(
          children: [
            const Text(
              'Your Library',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C5CFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showCreatePlaylistDialog(),
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'New Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (playlists.isNotEmpty) ...[
          const Text(
            'Custom Playlists',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: playlists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final pl = playlists[index];
                return PerformanceLiquidLens(
                  style: PerformanceGlassStyles.menu,
                  child: Container(
                    width: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFF171A24),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF7C5CFF).withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          children: [
                            const Icon(
                              Icons.playlist_play_rounded,
                              color: Color(0xFF7C5CFF),
                              size: 26,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pl.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${pl.tracks.length} tracks',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Action buttons — icon-only to avoid overflow
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _SmallActionButton(
                              icon: Icons.play_arrow_rounded,
                              tooltip: 'Play',
                              onTap: () {
                                if (pl.tracks.isEmpty) return;
                                _playerController.playTrack(
                                  pl.tracks.first,
                                  playlistQueue: pl.tracks,
                                );
                              },
                            ),
                            _SmallActionButton(
                              icon: Icons.shuffle_rounded,
                              tooltip: 'Shuffle',
                              onTap: () {
                                if (pl.tracks.isEmpty) return;
                                final shuffled = List<MusicTrack>.from(
                                  pl.tracks,
                                )..shuffle();
                                _playerController.playTrack(
                                  shuffled.first,
                                  playlistQueue: shuffled,
                                );
                              },
                            ),
                            _SmallActionButton(
                              icon: Icons.open_in_full_rounded,
                              tooltip: 'Open',
                              onTap: () =>
                                  setState(() => _activePlaylistModal = pl),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
        ],

        Row(
          children: [
            const Text(
              'Favorite Songs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (liked.isNotEmpty) ...[
              _SmallActionButton(
                icon: Icons.play_arrow_rounded,
                label: 'Play All',
                onTap: () => _playerController.playTrack(
                  liked.first,
                  playlistQueue: liked,
                ),
              ),
              const SizedBox(width: 8),
              _SmallActionButton(
                icon: Icons.shuffle_rounded,
                label: 'Shuffle',
                onTap: () {
                  final shuffled = List<MusicTrack>.from(liked)..shuffle();
                  _playerController.playTrack(
                    shuffled.first,
                    playlistQueue: shuffled,
                  );
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (liked.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36.0),
            child: Center(
              child: Text(
                'No favorite tracks yet. Heart any track to save it here.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: liked.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final track = liked[index];
              return _OctaveTrackRow(
                track: track,
                isPlaying:
                    _playerController.currentTrack?.id == track.id &&
                    _playerController.isPlaying,
                isCurrent: _playerController.currentTrack?.id == track.id,
                onTap: () =>
                    _playerController.playTrack(track, playlistQueue: liked),
                onMoreTap: () => _showAddToPlaylistMenu(track),
              );
            },
          ),
      ],
    );
  }

  Widget _filterTab(String label) {
    final isSelected =
        _selectedFilter == label ||
        (label.startsWith(_selectedFilter) && _selectedFilter != 'All');
    return GestureDetector(
      onTap: () {
        setState(() {
          if (label.startsWith('Tracks'))
            _selectedFilter = 'Tracks';
          else if (label.startsWith('Artists'))
            _selectedFilter = 'Artists';
          else if (label.startsWith('Albums'))
            _selectedFilter = 'Albums';
          else
            _selectedFilter = 'All';
        });
      },
      child: PerformanceLiquidLens(
        style: PerformanceGlassStyles.menuButton,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF7C5CFF)
                : const Color(0xFF171A24),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF7C5CFF)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Keyboard Shortcuts Modal Helper (_OctaveShortcutsModal)
// ─────────────────────────────────────────────────────────────────────────────
class _OctaveShortcutsModal extends StatelessWidget {
  final VoidCallback onClose;

  const _OctaveShortcutsModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      {'key': 'Space / K', 'action': 'Toggle Play / Pause'},
      {'key': 'J', 'action': 'Rewind 5 seconds'},
      {'key': 'L', 'action': 'Fast Forward 5 seconds'},
      {'key': 'M', 'action': 'Mute / Unmute Volume'},
      {'key': 'Q', 'action': 'Toggle Queue Drawer'},
      {'key': 'F', 'action': 'Toggle Fullscreen Player'},
      {'key': '?', 'action': 'Open Shortcuts Guide'},
    ];

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            width: 480,
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.keyboard_rounded,
                      color: Color(0xFF7C5CFF),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Keyboard Shortcuts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  itemCount: shortcuts.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10, height: 16),
                  itemBuilder: (context, index) {
                    final s = shortcuts[index];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s['action']!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C202E),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            s['key']!,
                            style: const TextStyle(
                              color: Color(0xFF7C5CFF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Synced Lyrics Drawer Panel (_OctaveLyricsDrawer)
// ─────────────────────────────────────────────────────────────────────────────
class _OctaveLyricsDrawer extends StatelessWidget {
  final MusicTrack track;
  final VoidCallback onClose;

  const _OctaveLyricsDrawer({required this.track, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.sheet,
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          color: const Color(0xFF0F121C).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.format_quote_rounded,
                  color: Color(0xFF7C5CFF),
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Synced Lyrics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: track.coverUrl,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      track.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      track.artist,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '♪ Syncing Hi-Fi Lyrics...',
                      style: TextStyle(
                        color: Color(0xFF7C5CFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Live lyrics stream active for this track.',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────
class _OctaveMobileBottomNav extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabSelected;

  const _OctaveMobileBottomNav({
    required this.activeTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = [
      {'label': 'Home', 'icon': Icons.home_rounded},
      {'label': 'Search', 'icon': Icons.search_rounded},
      {'label': 'Browse', 'icon': Icons.grid_view_rounded},
      {'label': 'Radio', 'icon': Icons.radio_rounded},
      {'label': 'Library', 'icon': Icons.library_music_rounded},
    ];

    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.dock,
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E14).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: navItems.map((item) {
            final label = item['label'] as String;
            final icon = item['icon'] as IconData;
            final isSelected = activeTab == label;

            return GestureDetector(
              onTap: () => onTabSelected(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF7C5CFF).withValues(alpha: 0.20)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? const Color(0xFF7C5CFF)
                          : Colors.white60,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Playlist Detail Modal
// ─────────────────────────────────────────────────────────────────────────────
class _OctavePlaylistDetailModal extends StatefulWidget {
  final UserPlaylist playlist;
  final VoidCallback onClose;
  final Function(MusicTrack, List<MusicTrack>) onPlayTrack;

  const _OctavePlaylistDetailModal({
    required this.playlist,
    required this.onClose,
    required this.onPlayTrack,
  });

  @override
  State<_OctavePlaylistDetailModal> createState() =>
      _OctavePlaylistDetailModalState();
}

class _OctavePlaylistDetailModalState
    extends State<_OctavePlaylistDetailModal> {
  void _playAll() {
    if (widget.playlist.tracks.isEmpty) return;
    widget.onPlayTrack(widget.playlist.tracks.first, widget.playlist.tracks);
  }

  void _shuffle() {
    if (widget.playlist.tracks.isEmpty) return;
    final shuffled = List<MusicTrack>.from(widget.playlist.tracks)..shuffle();
    widget.onPlayTrack(shuffled.first, shuffled);
  }

  @override
  Widget build(BuildContext context) {
    final tracks = widget.playlist.tracks;
    final player = MusicPlayerController.instance;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            width: 680,
            height: 580,
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    const Icon(
                      Icons.playlist_play_rounded,
                      color: Color(0xFF7C5CFF),
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.playlist.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${tracks.length} tracks',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Play All + Shuffle buttons
                if (tracks.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7C5CFF),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _playAll,
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            'Play All',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _shuffle,
                          icon: const Icon(
                            Icons.shuffle_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            'Shuffle',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),

                // Track list
                Expanded(
                  child: tracks.isEmpty
                      ? const Center(
                          child: Text(
                            'Playlist is empty',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.separated(
                          itemCount: tracks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final track = tracks[index];
                            return _OctaveTrackRow(
                              track: track,
                              isPlaying:
                                  player.currentTrack?.id == track.id &&
                                  player.isPlaying,
                              isCurrent: player.currentTrack?.id == track.id,
                              onTap: () => widget.onPlayTrack(track, tracks),
                              onDeleteTap: () async {
                                await OctaveLibraryService.instance
                                    .removeTrackFromPlaylist(
                                      widget.playlist.id,
                                      track.id,
                                    );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Track Row
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Small action button used on playlist cards and the library view
// ─────────────────────────────────────────────────────────────────────────────

class _SmallActionButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
  });

  @override
  State<_SmallActionButton> createState() => _SmallActionButtonState();
}

class _SmallActionButtonState extends State<_SmallActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: EdgeInsets.symmetric(
            horizontal: widget.label != null ? 10 : 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF7C5CFF).withValues(alpha: 0.22)
                : const Color(0xFF7C5CFF).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF7C5CFF).withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: const Color(0xFF7C5CFF), size: 16),
              if (widget.label != null) ...[
                const SizedBox(width: 4),
                Text(
                  widget.label!,
                  style: const TextStyle(
                    color: Color(0xFF7C5CFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Track Row
// ─────────────────────────────────────────────────────────────────────────────

class _OctaveTrackRow extends StatelessWidget {
  final MusicTrack track;
  final bool isPlaying;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;
  final VoidCallback? onDeleteTap;

  const _OctaveTrackRow({
    required this.track,
    required this.isPlaying,
    required this.isCurrent,
    required this.onTap,
    this.onMoreTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: PerformanceLiquidLens(
        style: PerformanceGlassStyles.menu,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCurrent
                ? const Color(0xFF191C28)
                : const Color(0xFF11131C).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrent
                  ? const Color(0xFF7C5CFF)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: track.coverUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  memCacheWidth: 150,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(
                        color: isCurrent
                            ? const Color(0xFF7C5CFF)
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.artist} · ${track.album}',
                      style: const TextStyle(
                        color: Color(0xFF9E9EA8),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                track.formattedDuration,
                style: const TextStyle(color: Color(0xFF6B6B76), fontSize: 12),
              ),
              if (onMoreTap != null)
                IconButton(
                  icon: const Icon(
                    Icons.playlist_add_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: onMoreTap,
                ),
              if (onDeleteTap != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  onPressed: onDeleteTap,
                ),
              const SizedBox(width: 4),
              Icon(
                isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                color: isCurrent ? const Color(0xFF7C5CFF) : Colors.white54,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Now Playing Queue Drawer
// ─────────────────────────────────────────────────────────────────────────────
class _OctaveQueueDrawer extends StatelessWidget {
  final VoidCallback onClose;

  const _OctaveQueueDrawer({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final player = MusicPlayerController.instance;
    final queue = player.playlist;
    final currentIndex = player.currentIndex;

    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.sheet,
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          color: const Color(0xFF0F121C).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.queue_music_rounded,
                  color: Color(0xFF7C5CFF),
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Now Playing Queue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: queue.isEmpty
                  ? const Center(
                      child: Text(
                        'Queue is empty',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.separated(
                      itemCount: queue.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final track = queue[index];
                        final isCurrent = index == currentIndex;

                        return GestureDetector(
                          onTap: () =>
                              player.playTrack(track, playlistQueue: queue),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? const Color(
                                      0xFF7C5CFF,
                                    ).withValues(alpha: 0.20)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isCurrent
                                  ? Border.all(
                                      color: const Color(
                                        0xFF7C5CFF,
                                      ).withValues(alpha: 0.5),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: track.coverUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 120,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        style: TextStyle(
                                          color: isCurrent
                                              ? const Color(0xFF7C5CFF)
                                              : Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        track.artist,
                                        style: const TextStyle(
                                          color: Color(0xFF9E9EA8),
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCurrent)
                                  const Icon(
                                    Icons.volume_up_rounded,
                                    color: Color(0xFF7C5CFF),
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Artist Details Modal
// ─────────────────────────────────────────────────────────────────────────────
class _OctaveArtistDetailModal extends StatelessWidget {
  final OctaveArtistDetails details;
  final VoidCallback onClose;
  final Function(MusicTrack, List<MusicTrack>) onPlayTrack;
  final Function(MusicTrack) onAddToPlaylist;

  const _OctaveArtistDetailModal({
    required this.details,
    required this.onClose,
    required this.onPlayTrack,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final artist = details.artist;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            width: 720,
            height: 640,
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: artist.pictureUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 600,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF0F121C),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: onClose,
                      ),
                    ),
                    Positioned(
                      left: 24,
                      bottom: 16,
                      child: Text(
                        artist.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    children: [
                      if (details.topTracks.isNotEmpty) ...[
                        const Text(
                          'Top Songs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: details.topTracks.length.clamp(0, 6),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final track = details.topTracks[index];
                            return _OctaveTrackRow(
                              track: track,
                              isPlaying: false,
                              isCurrent: false,
                              onTap: () =>
                                  onPlayTrack(track, details.topTracks),
                              onMoreTap: () => onAddToPlaylist(track),
                            );
                          },
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop Left Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _OctaveSidebar extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabSelected;

  const _OctaveSidebar({required this.activeTab, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    final navItems = [
      {'label': 'Home', 'icon': Icons.home_rounded},
      {'label': 'Search', 'icon': Icons.search_rounded},
      {'label': 'Browse', 'icon': Icons.grid_view_rounded},
      {'label': 'Radio', 'icon': Icons.radio_rounded},
      {'label': 'Podcasts', 'icon': Icons.mic_rounded},
      {'label': 'Library', 'icon': Icons.library_music_rounded},
    ];

    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.sheet,
      child: Container(
        width: 230,
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E14).withValues(alpha: 0.85),
          border: Border(
            right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 20, bottom: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C5CFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Music',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: navItems.map((item) {
                    final label = item['label'] as String;
                    final icon = item['icon'] as IconData;
                    final isSelected = activeTab == label;

                    final navWidget = Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onTabSelected(label),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF191C28)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(
                                        0xFF7C5CFF,
                                      ).withValues(alpha: 0.4),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 20,
                                  color: isSelected
                                      ? const Color(0xFF7C5CFF)
                                      : Colors.white60,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    if (isSelected) {
                      return PerformanceLiquidLens(
                        style: PerformanceGlassStyles.menuButton,
                        child: navWidget,
                      );
                    }
                    return navWidget;
                  }).toList(),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: PerformanceLiquidLens(
                  style: PerformanceGlassStyles.menu,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151C).withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF7C5CFF),
                          ),
                          child: const Center(
                            child: Text(
                              'O',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Music',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Octave Top Header Chrome Bar
// ─────────────────────────────────────────────────────────────────────────────
class _OctaveTopHeader extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final void Function(Offset?) onSettingsTap;
  final VoidCallback onShortcutsTap;

  const _OctaveTopHeader({
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSettingsTap,
    required this.onShortcutsTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.sheet,
      child: Container(
        padding: EdgeInsets.only(
          top: topPadding + 8,
          bottom: 10,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF08090C).withValues(alpha: 0.82),
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.4),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PerformanceLiquidLens(
                style: PerformanceGlassStyles.menu,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF13151C).withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF7C5CFF),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          focusNode: searchFocusNode,
                          onChanged: onSearchChanged,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search music, artists, playlists...',
                            hintStyle: TextStyle(
                              color: Color(0xFF66666B),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: onClearSearch,
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(
                Icons.keyboard_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 22,
              ),
              onPressed: onShortcutsTap,
              tooltip: 'Keyboard Shortcuts (?)',
            ),
            Builder(
              builder: (context) {
                return IconButton(
                  icon: Icon(
                    Icons.settings_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 22,
                  ),
                  onPressed: () {
                    final box = context.findRenderObject() as RenderBox?;
                    final offset = box != null
                        ? box.localToGlobal(box.size.center(Offset.zero))
                        : null;
                    onSettingsTap(offset);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Octave Hero Featured Billboard
// ─────────────────────────────────────────────────────────────────────────────
class _OctaveHeroBillboard extends StatelessWidget {
  final MusicTrack track;
  final VoidCallback onPlayTap;
  final VoidCallback onSaveTap;
  final VoidCallback onAddToPlaylistTap;
  final bool isSaved;

  const _OctaveHeroBillboard({
    required this.track,
    required this.onPlayTap,
    required this.onSaveTap,
    required this.onAddToPlaylistTap,
    required this.isSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: PerformanceLiquidLens(
        style: PerformanceGlassStyles.sheet,
        child: Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF7C5CFF).withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: track.coverUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 600,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF08090C).withValues(alpha: 0.95),
                        const Color(0xFF08090C).withValues(alpha: 0.60),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 28,
                  bottom: 28,
                  right: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF7C5CFF,
                          ).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFF7C5CFF,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          'FEATURED',
                          style: TextStyle(
                            color: Color(0xFF7C5CFF),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${track.artist} · ${track.album}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: onPlayTap,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            label: const Text(
                              'Play',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C5CFF),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 6,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: onSaveTap,
                            icon: Icon(
                              isSaved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isSaved
                                  ? const Color(0xFF7C5CFF)
                                  : Colors.white,
                              size: 20,
                            ),
                            label: Text(
                              isSaved ? 'Saved' : 'Save',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(
                              Icons.playlist_add_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: onAddToPlaylistTap,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trending Artists
// ─────────────────────────────────────────────────────────────────────────────
class _OctaveTrendingArtists extends StatelessWidget {
  final List<MusicArtist> artists;
  final ValueChanged<MusicArtist> onArtistTap;

  const _OctaveTrendingArtists({
    required this.artists,
    required this.onArtistTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Text(
            'Trending Artists',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              return Padding(
                padding: const EdgeInsets.only(right: 18.0),
                child: GestureDetector(
                  onTap: () => onArtistTap(artist),
                  child: Column(
                    children: [
                      PerformanceLiquidLens(
                        style: PerformanceGlassStyles.menuButton,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFF7C5CFF,
                              ).withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: artist.pictureUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 84,
                        child: Text(
                          artist.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Slider
// ─────────────────────────────────────────────────────────────────────────────
class _OctaveCategorySlider extends StatelessWidget {
  final String title;
  final List<MusicTrack> tracks;
  final Function(MusicTrack)? onAddToPlaylist;

  const _OctaveCategorySlider({
    required this.title,
    required this.tracks,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final sizing = _OctaveCardSizing.fromWidth(
      MediaQuery.sizeOf(context).width,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: 12),
          SizedBox(
            height: sizing.totalHeight,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return SizedBox(
                  width: sizing.cardWidth,
                  child: MusicTrackCard(
                    track: track,
                    playlist: tracks,
                    onAddToPlaylist: onAddToPlaylist != null
                        ? () => onAddToPlaylist!(track)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OctaveCardSizing {
  final double cardWidth;
  final double posterHeight;
  final double totalHeight;

  _OctaveCardSizing({
    required this.cardWidth,
    required this.posterHeight,
    required this.totalHeight,
  });

  factory _OctaveCardSizing.fromWidth(double screenWidth) {
    double cardWidth;
    if (screenWidth < 360)
      cardWidth = 140;
    else if (screenWidth < 600)
      cardWidth = 156;
    else if (screenWidth < 1000)
      cardWidth = 175;
    else
      cardWidth = 190;

    final posterHeight = cardWidth;
    final totalHeight = posterHeight + 60;

    return _OctaveCardSizing(
      cardWidth: cardWidth,
      posterHeight: posterHeight,
      totalHeight: totalHeight,
    );
  }
}

class MusicTrackCard extends StatefulWidget {
  final MusicTrack track;
  final List<MusicTrack> playlist;
  final VoidCallback? onAddToPlaylist;

  const MusicTrackCard({
    super.key,
    required this.track,
    required this.playlist,
    this.onAddToPlaylist,
  });

  @override
  State<MusicTrackCard> createState() => _MusicTrackCardState();
}

class _MusicTrackCardState extends State<MusicTrackCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final isCurrentTrack =
        MusicPlayerController.instance.currentTrack?.id == track.id;
    final isPlaying =
        isCurrentTrack && MusicPlayerController.instance.isPlaying;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () => MusicPlayerController.instance.playTrack(
          track,
          playlistQueue: widget.playlist,
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.97 : (_hovered ? 1.045 : 1.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PerformanceLiquidLens(
                    style: PerformanceGlassStyles.menuButton,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 170),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: _hovered ? 0.60 : 0.34,
                            ),
                            blurRadius: _hovered ? 30 : 18,
                            offset: Offset(0, _hovered ? 16 : 8),
                          ),
                          if (_hovered || isCurrentTrack)
                            BoxShadow(
                              color: const Color(
                                0xFF7C5CFF,
                              ).withValues(alpha: 0.30),
                              blurRadius: 32,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0xFF171A23)),
                            CachedNetworkImage(
                              imageUrl: track.coverUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 300,
                            ),
                            if (widget.onAddToPlaylist != null)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: AnimatedOpacity(
                                  opacity: _hovered ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 150),
                                  child: GestureDetector(
                                    onTap: widget.onAddToPlaylist,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.70,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.playlist_add_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: AnimatedOpacity(
                                opacity: (_hovered || isCurrentTrack) ? 1 : 0,
                                duration: const Duration(milliseconds: 150),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF7C5CFF),
                                  ),
                                  child: Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isCurrentTrack
                        ? const Color(0xFF7C5CFF)
                        : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E9EA8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OctaveAlbumCard extends StatelessWidget {
  final MusicAlbum album;
  final VoidCallback onTap;

  const _OctaveAlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PerformanceLiquidLens(
              style: PerformanceGlassStyles.menuButton,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: album.coverUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            album.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF9E9EA8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky Octave Player Bar at Bottom
// ─────────────────────────────────────────────────────────────────────────────
class _OctaveBottomPlayerBar extends StatelessWidget {
  final bool isFavorite;
  final bool showQueue;
  final bool showLyrics;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onQueueToggle;
  final VoidCallback onLyricsToggle;
  final VoidCallback onExpand;

  const _OctaveBottomPlayerBar({
    required this.isFavorite,
    required this.showQueue,
    required this.showLyrics,
    required this.onFavoriteToggle,
    required this.onQueueToggle,
    required this.onLyricsToggle,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final player = MusicPlayerController.instance;
    final track = player.currentTrack!;
    final pos = player.position;
    final dur = player.duration;
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.dock,
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E14).withValues(alpha: 0.88),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: onExpand,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: track.coverUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      memCacheWidth: 150,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: isDesktop ? 160 : 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          track.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          style: const TextStyle(
                            color: Color(0xFF9E9EA8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isFavorite ? const Color(0xFF7C5CFF) : Colors.white54,
                size: 18,
              ),
              onPressed: onFavoriteToggle,
            ),
            if (isDesktop) const Spacer(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: player.previousTrack,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF7C5CFF),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: player.togglePlayPause,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: player.nextTrack,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _formatDuration(pos),
                          style: const TextStyle(
                            color: Color(0xFF6B6B76),
                            fontSize: 10,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 4,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10,
                              ),
                              activeTrackColor: const Color(0xFF7C5CFF),
                              inactiveTrackColor: Colors.white.withValues(
                                alpha: 0.12,
                              ),
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: pos.inSeconds.toDouble().clamp(
                                0.0,
                                dur.inSeconds > 0
                                    ? dur.inSeconds.toDouble()
                                    : 1.0,
                              ),
                              min: 0.0,
                              max: dur.inSeconds > 0
                                  ? dur.inSeconds.toDouble()
                                  : 1.0,
                              onChanged: (val) =>
                                  player.seekTo(Duration(seconds: val.toInt())),
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(dur),
                          style: const TextStyle(
                            color: Color(0xFF6B6B76),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isDesktop) const Spacer(),
            Row(
              children: [
                if (isDesktop) ...[
                  IconButton(
                    icon: Icon(
                      player.volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () =>
                        player.setVolume(player.volume > 0 ? 0.0 : 1.0),
                  ),
                  SizedBox(
                    width: 70,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 3,
                        ),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withValues(
                          alpha: 0.15,
                        ),
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: player.volume,
                        onChanged: (v) => player.setVolume(v),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.format_quote_rounded,
                    color: showLyrics
                        ? const Color(0xFF7C5CFF)
                        : Colors.white70,
                    size: 18,
                  ),
                  onPressed: onLyricsToggle,
                  tooltip: 'Lyrics',
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.queue_music_rounded,
                    color: showQueue ? const Color(0xFF7C5CFF) : Colors.white70,
                    size: 18,
                  ),
                  onPressed: onQueueToggle,
                  tooltip: 'Queue (Q)',
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Color(0xFF7C5CFF),
                    size: 22,
                  ),
                  onPressed: onExpand,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Octave Expanded Player Modal
// ─────────────────────────────────────────────────────────────────────────────
class _OctaveExpandedPlayer extends StatelessWidget {
  final VoidCallback onDismiss;

  const _OctaveExpandedPlayer({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final player = MusicPlayerController.instance;
    final track = player.currentTrack!;
    final pos = player.position;
    final dur = player.duration;
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    final playerCard = PerformanceLiquidLens(
      style: PerformanceGlassStyles.sheet,
      child: Container(
        width: isDesktop ? 480 : double.infinity,
        height: isDesktop ? 640 : double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0F121C).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(isDesktop ? 28 : 0),
          border: isDesktop
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                )
              : null,
          boxShadow: isDesktop
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: const Color(0xFF7C5CFF).withValues(alpha: 0.25),
                    blurRadius: 48,
                  ),
                ]
              : [],
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: onDismiss,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 24,
                      ),
                      onPressed: onDismiss,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 36,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: const Color(
                          0xFF7C5CFF,
                        ).withValues(alpha: player.isPlaying ? 0.40 : 0.15),
                        blurRadius: 44,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: CachedNetworkImage(
                      imageUrl: track.coverUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${track.artist} · ${track.album}',
                      style: const TextStyle(
                        color: Color(0xFF9E9EA8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        activeTrackColor: const Color(0xFF7C5CFF),
                        inactiveTrackColor: Colors.white.withValues(
                          alpha: 0.15,
                        ),
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: pos.inSeconds.toDouble().clamp(
                          0.0,
                          dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0,
                        ),
                        min: 0.0,
                        max: dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0,
                        onChanged: (val) =>
                            player.seekTo(Duration(seconds: val.toInt())),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(pos),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDuration(dur),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 34,
                    icon: const Icon(
                      Icons.skip_previous_rounded,
                      color: Colors.white,
                    ),
                    onPressed: player.previousTrack,
                  ),
                  const SizedBox(width: 20),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF7C5CFF),
                    ),
                    child: IconButton(
                      iconSize: 34,
                      icon: Icon(
                        player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      onPressed: player.togglePlayPause,
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    iconSize: 34,
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                    ),
                    onPressed: player.nextTrack,
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );

    if (isDesktop) {
      return GestureDetector(
        onTap: onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.70),
          child: Center(
            child: GestureDetector(onTap: () {}, child: playerCard),
          ),
        ),
      );
    }

    return playerCard;
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
