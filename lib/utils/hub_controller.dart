import 'package:flutter/material.dart';

import 'app_hub.dart';

/// A single section within a hub (e.g. Media -> Movies, Books -> Manga).
class HubSection {
  final String id;
  final String label;
  final IconData icon;

  const HubSection({required this.id, required this.label, required this.icon});
}

/// Global controller for the top-level navigation: which hub is active and
/// which section within that hub. The header and the hubs both read/write this
/// so navigation stays in sync.
class HubController extends ChangeNotifier {
  static final HubController instance = HubController._internal();
  HubController._internal();

  AppHub _currentHub = AppHub.media;
  String _mediaSection = 'watch';
  String _booksSection = 'books';
  String _musicTab = 'Music';

  // Each hub exposes exactly four sections, so a pair that would otherwise
  // make a fifth is one section with a sub-tab instead. This holds which
  // side of that pair is showing. Comics and Manga used to be paired the
  // same way (readableType) -- they're independent top-level sections now
  // that Audiobooks moved here to make room, see currentSections below.
  String _watchType = 'movie'; // 'movie' | 'series'
  String _spokenAudioType = 'podcasts'; // 'podcasts' | 'audiobooks'

  // Whether Settings is showing in place of the current hub's content.
  // Nav chrome (hub switcher, section row) stays visible and clickable the
  // whole time -- switching hub or section below implicitly leaves Settings.
  bool _settingsOpen = false;

  AppHub get currentHub => _currentHub;
  String get mediaSection => _mediaSection;
  String get booksSection => _booksSection;
  String get musicTab => _musicTab;
  String get watchType => _watchType;
  String get spokenAudioType => _spokenAudioType;
  bool get settingsOpen => _settingsOpen;

  void openSettings() {
    if (_settingsOpen) return;
    _settingsOpen = true;
    notifyListeners();
  }

  void closeSettings() {
    if (!_settingsOpen) return;
    _settingsOpen = false;
    notifyListeners();
  }

  void setWatchType(String type) {
    if (_watchType == type) return;
    _watchType = type;
    notifyListeners();
  }

  void setSpokenAudioType(String type) {
    if (_spokenAudioType == type) return;
    _spokenAudioType = type;
    notifyListeners();
  }

  void setHub(AppHub hub) {
    // Falls through even when the hub itself is unchanged, so re-tapping the
    // already-active hub pill while Settings is open still closes it.
    if (_currentHub == hub && !_settingsOpen) return;
    _currentHub = hub;
    _settingsOpen = false;
    notifyListeners();
  }

  void setMediaSection(String id) {
    if (_mediaSection == id && !_settingsOpen) return;
    _mediaSection = id;
    _settingsOpen = false;
    notifyListeners();
  }

  void setBooksSection(String id) {
    if (_booksSection == id && !_settingsOpen) return;
    _booksSection = id;
    _settingsOpen = false;
    notifyListeners();
  }

  void setMusicTab(String tab) {
    if (_musicTab == tab && !_settingsOpen) return;
    _musicTab = tab;
    _settingsOpen = false;
    notifyListeners();
  }

  /// The sections available for the current hub.
  ///
  /// Every hub has exactly four, so the mobile bottom bar and the desktop chip
  /// row have a fixed, evenly-divisible shape. A pair that would make a fifth
  /// (Movies/Series in Watch, Podcasts/Audiobooks in Listen) is one section
  /// with a sub-tab instead.
  List<HubSection> get currentSections {
    switch (_currentHub) {
      case AppHub.media:
        return const [
          HubSection(
            id: 'watch',
            label: 'Movies & Series',
            icon: Icons.movie_rounded,
          ),
          HubSection(
            id: 'anime',
            label: 'Anime',
            icon: Icons.animation_rounded,
          ),
          HubSection(id: 'iptv', label: 'Live TV', icon: Icons.live_tv_rounded),
          HubSection(
            id: 'collection',
            label: 'Library',
            icon: Icons.video_library_rounded,
          ),
        ];
      case AppHub.books:
        return const [
          HubSection(
            id: 'books',
            label: 'Books',
            icon: Icons.import_contacts_rounded,
          ),
          HubSection(
            id: 'comics',
            label: 'Comics',
            icon: Icons.menu_book_rounded,
          ),
          HubSection(
            id: 'manga',
            label: 'Manga',
            icon: Icons.auto_stories_rounded,
          ),
          HubSection(
            id: 'collection',
            label: 'Library',
            icon: Icons.collections_bookmark_rounded,
          ),
        ];
      case AppHub.music:
        return const [
          HubSection(
            id: 'Music',
            label: 'Music',
            icon: Icons.music_note_rounded,
          ),
          // Podcasts and Audiobooks share this section via a sub-tab
          // (spokenAudioType) -- both episodic spoken audio, same as
          // Movies/Series sharing Watch's own equivalent section.
          HubSection(
            id: 'Podcasts',
            label: 'Podcasts & Audiobooks',
            icon: Icons.podcasts_rounded,
          ),
          HubSection(id: 'Radio', label: 'Radio', icon: Icons.radio_rounded),
          HubSection(
            id: 'Library',
            label: 'Library',
            icon: Icons.library_music_rounded,
          ),
        ];
    }
  }

  /// The id of the active section within the current hub.
  String get currentSectionId {
    switch (_currentHub) {
      case AppHub.media:
        return _mediaSection;
      case AppHub.books:
        return _booksSection;
      case AppHub.music:
        return _musicTab;
    }
  }

  void setCurrentSection(String id) {
    switch (_currentHub) {
      case AppHub.media:
        setMediaSection(id);
        break;
      case AppHub.books:
        setBooksSection(id);
        break;
      case AppHub.music:
        setMusicTab(id);
        break;
    }
  }
}
