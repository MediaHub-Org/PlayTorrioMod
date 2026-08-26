# Changelog

All notable changes to PlayTorrio V3 will be documented in this file.

## [unreleased] — 2026-08-22

### Cleanup — 2026-08-27
- Deleted `lib/models/download/download_item.dart`'s `DownloadItem` — zero references anywhere, superseded by `DownloadTask` when the download manager was rewritten (merged from upstream, see below).
- `AppRadii` (added with the frontend nav-chrome work, previously unused) now has a real consumer: `hub_page.dart`'s content-panel corner radius.
- `AdaptiveNavShell`'s mobile top bar now reuses `SidebarLogo` instead of reimplementing its icon-loading call.
- `TopBar` now reads hub labels/icons from `AppHub.navLabel`/`.navIcon` instead of its own separate hardcoded list — one source of truth instead of two. `TopBar`/`SectionTopBar` also now reference `AppSpacing`/`AppRadii` wherever their existing values actually matched the token scale (16px padding, 12px radius).
- Also deleted the merged-and-stale `upstream-merge-attempt` git branch/worktree from an earlier merge pass.

### Navigation & play bar — 2026-08-27
- **Music detail pages use a back arrow, not a close X**: `_MusicArtistDetailPage`/`_MusicAlbumDetailPage`/`_MusicCuratedPlaylistDetailPage`/`_MusicUserPlaylistDetailPage` are real pushed routes, same as `DetailsPage`/`AudiobookDetailPage`, but used a modal-style close icon. Swapped to the same back-arrow convention every other detail page follows.
- Investigated Radio/Podcasts' missing back button: both are peer-tab switches inside `MusicPage` (same model as Movies/Series/Anime's section chips), not pushed routes — ruled working-as-designed, no back button needed. Books' lack of a browse view (search-only) is a separate, real gap, tracked in ROADMAP.
- **Like button on the universal play bar**: `PlaybackCoordinator.activate()` gained optional `isLiked`/`onToggleLike` callbacks (music tracks only). `UniversalPlayBar` shows a heart whenever the active source supports it, wired to `MusicLibraryService.isTrackLiked`/`toggleLikeTrack`, so a track can be liked without opening the full player.
- **Download button on each source card**: `WatchScreen`'s source-selection list (where a `StreamSource` is already resolved per row before playback) gained a download icon next to the play chevron, calling `DownloadService.startDownload` directly — mirrors the existing in-player download button's dedup/folder-picker/snackbar logic, but lets a user queue a download without opening playback first.

### Fixed — 2026-08-26
- **"Unknown error" dialog on Windows app close**: `WindowService` never intercepted the close event, so the OS killed the process while `LocalStreamProxy`'s loopback HTTP server (and other background services) were still live. Now calls `windowManager.setPreventClose(true)` on init and runs a real shutdown sequence in a new `onWindowClose` handler (`PlaybackCoordinator.stopActive()`, `LocalStreamProxy.instance.stop()`, `TorrentStreamService().stop()`, then `windowManager.destroy()`) before actually closing.

### Merged upstream (round 2) — 2026-08-26
- Reconciled 5 more upstream commits (`d552781`..`18e1910`) into `pr/navigation-cleanup`: a SubtitleCat subtitle provider, a rewritten player keyboard/volume system (arrow-key volume with HUD, mouse-wheel scroll volume, M/space/K/J/L shortcuts, proper text-input passthrough via `Focus` instead of `KeyboardListener`), true borderless OS fullscreen, a new Arabic anime section (`AnimeSearchPage`, `AnimeArabicDetailsPage`, `AnimeArabicStreamSheet`), new anime extractors (AniDB, MegaPlay, ReCloud, TryEmbed, replacing AllAnime/Anikoto/Miruro), a media-title cleaner, `torrent_stream_service`, magnet/stream-link paste detection in search, and updated app icons across platforms.
- Kept our nav architecture over upstream's per-page Home-Page-style chrome (dropped their Floating Glass App Bar and Liquid Dock navbar from `anime_page.dart`/`iptv_page.dart` again); merged rather than replaced where both sides added real, compatible features — our genre filter alongside their Arabic-mode browsing in `anime_page.dart`, our brightness/volume drag gestures alongside their keyboard/scroll-wheel volume in `player_screen.dart`, our `SearchScope` content-type scoping alongside their broader unscoped-search default.
- Caught and fixed a genuine upstream bug via its own new widget test: `AnimeSearchPage`'s `late bool _isArabicMode` was never initialized from `widget.initialArabicMode`, crashing on open.
- Verified clean: `flutter analyze` 0 errors, 141/147 tests passing (6 known pre-existing failures unrelated to this branch), Windows release build succeeds.

### Frontend nav chrome — 2026-08-26
- Added `AppBreakpoints`/`ScreenTier` (mobile/tablet/desktop, 600/900 cutoffs) as the single source of truth for responsive tiers, and `AppSpacing`/`AppRadii` as a shared 8pt-grid token scale — both follow `AppThemeService`'s existing static-service pattern.
- Added `AdaptiveNavShell`: `HubPage` now shows a thumb-reachable bottom tab bar on mobile (matching Netflix/Disney+/Stremio's mobile nav placement) instead of the same top-anchored `TopBar` used on every screen size. Tablet/desktop keep `TopBar` unchanged; the play bar's bottom margin on tablet also tightened from a leftover 76px to the correct 16px it already used on desktop.
- Additive-only pass: no existing service, model, or scraper touched; `TopBar`/`SectionTopBar` reused as-is. Full design and what's intentionally deferred (opportunistic migration of the 52 files with ad-hoc breakpoint checks, restyling `TopBar` onto the new tokens) is in `docs/superpowers/specs/2026-08-26-frontend-design-system-design.md`.

### Merged upstream — 2026-08-25
- Reconciled `ayman708-UX/PlayTorrioV3` main (8 commits since the last merge) with this fork's navigation restructure and everything shipped this session. Brings in: a full Trakt/Simkl cloud-sync rewrite, a download manager with a 5-provider Debrid engine (Real-Debrid, TorBox, AllDebrid, Premiumize, Debrid-Link), an app-wide `AppThemeService` color-palette system, per-content-type player customization (`AudiobookSettings`/`MusicSettings`/`MangaSettings`/`IptvSettings` "player studio" pages), a modularized settings page (401-line hub + category sub-pages, replacing the 1503-line monolith), and various player/scraper fixes.
- Kept our hub navigation, `PlaybackCoordinator` fixes, and this session's UI decisions (volume slider not shuffle, real pages not modals) layered inside upstream's new architecture rather than reverted by it. Dropped the old HomePage/LiquidDock-specific pieces (already removed from our nav) and ~1750 lines of now-dead pre-refactor UI superseded by upstream's own extracted widget files. Full resolution notes and per-file decisions are in the merge commit (`207a779`).
- Verified clean: `flutter analyze` 0 errors, full test suite passes, Windows release build succeeds.

### Fixed
- **Black screen on Windows launch**: the bottom play-bar was built by a `ListenableBuilder` sitting directly as a `Stack` child, returning `SizedBox.shrink()` normally but a bare `Positioned` when the Listen hub was active. Flutter's `Stack` doesn't handle a child flipping between Positioned and non-Positioned across rebuilds; it corrupted the whole window's paint — app was fully built underneath (confirmed via widget-tree dump) but rendered solid black. Fixed by wrapping it in a stable outer `Positioned`.
- Corrupted `scripts/run_windows.bat` (stray characters had mangled `if`/`echo`/`pushd` into invalid batch syntax).
- **Movies and Series showing identical content**: `TypeCatalogPage` only fetched in `initState()`, and switching the Watch section chip reused the same `State` instead of remounting — `widget.type` changed but the loaded list never refreshed. Gave each instance a `ValueKey(type)`.
- **Play bar Stop button didn't actually stop playback**: it reused the same "pause because another source took over" callback as the real Stop action, so the bar hid but the underlying music/audiobook controller kept playing in memory. Added a distinct `onFullStop` to `PlaybackCoordinator`, and a real `stop()` on `MusicPlayerController`/`AudiobookPlayerController` that disposes the controller and releases resources.
- **Anime hub failing to load**: `AnimePage` fetched 8 independent AniList queries through a single all-or-nothing `Future.wait` — any one failure blanked the whole page. Each section now catches its own error and degrades to empty instead of failing the page.
- **Album play/pause button had no animation**: replaced the instant `Icon` swap with `AnimatedIcons.play_pause` via `TweenAnimationBuilder`.
- **Gradle build noise on cross-drive setups**: Kotlin's incremental-compilation cache threw "different roots" errors when the project and pub cache live on different drives (harmless — build still completed — but surfaced as a false error in IDE Gradle integrations). Disabled via `kotlin.incremental=false`.
- **TopBar reading as hidden on detail pages**: it's structurally outside the nested navigator and can never actually be covered, but `DetailsPage`'s background (`0xFF0B0D12`) is nearly identical to the bar's own (`0xFF0B0D15`), separated only by an 8%-opacity 1px border — the boundary was invisible, not the bar. Raised the border contrast and added a drop shadow so it reads as a distinct bar over any page content.
- **Artist/Album/Curated-Playlist/User-Playlist opening as a fixed ~720×640 centered popup** instead of a real screen, inconsistent with every other detail view (`DetailsPage`, `AudiobookDetailPage`). Promoted all four to real pushed pages (`Navigator.push`, `Scaffold`-based). User playlist detail now derives its track list reactively from `MusicLibraryService` instead of holding a stale snapshot, so removing a track updates the page live.

### Live TV
- Added **Live TV** as a new section in the Watch hub (`lib/pages/iptv/`), wired through `HubController` alongside Movies/Series/Anime/Genres/Library.
- Added **multi-view**: a grid-view button in the Live TV app bar picks up to 4 channels and plays them at once, tap a tile to swap audio focus. Deliberately scoped to channels that already have a cached stream URL (`IptvChannelResultsStore`) instead of triggering fresh scans -- `IptvController`'s scan flow only tracks one active channel at a time, and extending that shared singleton to N concurrent scan contexts was a real risk to the existing single-channel flow for a first version. Each tile owns and disposes its own `VideoPlayerController` directly and the grid bypasses `PlaybackCoordinator` (several simultaneous video sources don't fit its single-active-source model), stopping whatever else was playing on entry instead.

### Books
- Added a **Books** section to the Read hub: search libgen.li (a live LibGen mirror, epub-only results), download, and read in-app. Ported from `ayman708-UX/PlayTorrioV2` (`books_service.dart`, `book_progress_service.dart`, `book_reader_screen.dart`) and restyled to match V3. The reader unzips the epub once, parses the OPF manifest/spine into a chapter list, and loads each chapter's own HTML file into a webview via a `file://` URL so relative image/CSS references resolve naturally. Chapter/scroll progress persists so "Continue Reading" survives restarts. New deps: `flutter_inappwebview`, `xml`; verified `flutter_inappwebview` actually compiles and links on Windows desktop via a full release build before landing, since webview plugins are historically the least reliable thing on that platform. V2's "focus mode" (one-line-at-a-time reading overlay) was left out as a scope cut for a first version.

### Podcasts
- Added a **Podcasts** section to the Listen hub: search via the iTunes Search API (free, no key) for discovery, then read episodes straight from each show's own RSS feed -- the standard way every podcast app sources audio. `PodcastPlayerController` mirrors `AudiobookPlayerController`'s `PlaybackCoordinator` wiring but simpler (one episode at a time, no chapters). PlayTorrioV2 has no podcast feature at all, so this is an original build, not a port.

### Backup & Restore
- Added **local JSON export/import** for user data (Settings → Backup & Restore): reads/writes the entire `SharedPreferences` store as one flat, versioned JSON file, so no per-service serializer was needed for the ~15 independent services that hold user data. Envelope schema is deliberately transport-agnostic so cloud sync later is a matter of shipping the same JSON elsewhere.

### Filters
- Added a **decade filter + sort dropdown** (Title A–Z/Z–A, Newest, Oldest) to the Movies and Series catalogs (`TypeCatalogPage`, shared by both). Decade options are derived from whichever years are actually present in the loaded catalog, so the dropdown never offers an empty result.
- Added a **genre filter to Anime**: picking a genre swaps the curated homepage rows for a single filtered grid (via `AnilistService.fetchByGenre`); picking "All Genres" reverts to the curated rows untouched. Extracted the filter dropdown button into a shared `lib/widgets/common/filter_dropdown.dart` used by both Movies/Series and Anime.

### Navigation
- **Moved Audiobooks from Listen to Read.** `AppHub`'s own doc comment already said Audiobooks belonged in the Read hub -- it had just drifted into Music's section list during the restructure. Now a real Read hub section (Manga, Comics, Audiobooks, Library) instead of nested inside the Music page's own tab switch.

### Cast
- Added **TMDB cast enrichment**: photos and character names for movies/series when an addon only supplies plain name strings, using the user's own free TMDB API key (Settings → TMDB). No-ops entirely with no key configured, and skips the network call when the addon's own cast data already has photos.

### Architecture
- `CollectionPage` now builds on the shared `LibraryTabs`/`LibraryEmptyState` widgets instead of hand-rolling its own `TabController`/`Scaffold`/`AppBar`/`TabBar` and empty-state layout, matching `BooksLibraryPage`. Also removed a dead leftover back button (`HubNavigator.goHome()`) from before the navigation restructure -- it re-selected the hub the page was already embedded in, a functional no-op, and no other Watch hub section has one.
- Extracted `_MusicModalShell` (the dimmed-backdrop + glass panel wrapper) out of all four music detail modals (Artist/Album/Curated Playlist/User Playlist) -- they were hand-duplicating that ~15-line shell exactly. Left each modal's actual header/body alone since the Artist modal's banner header is genuinely different from the other three's row header, rather than forcing all four into one over-parameterized widget.
- Extracted a `HorizontalSliderScroll` mixin out of `MovieSliderSection`/`IptvSliderSection`'s duplicated scroll-arrow logic, and found `MovieSliderSection` had its own private `_SliderArrow` -- a byte-for-byte duplicate of the already-shared `common/slider_arrow.dart` that `IptvSliderSection` was already using. Removed the duplicate and fixed that shared widget's deprecated `withOpacity()` calls now that it's the single canonical copy.
- Extracted `InteractiveCardShell` out of `MovieCard`/`IptvChannelCard`'s identical hover/press interaction physics (170ms easeOutCubic scale + lift, same everywhere but the press-scale value). Both cards no longer need their own hover/press state, so both went from `StatefulWidget` to `StatelessWidget` as a result.
- Extracted a `HeroCarouselAutoRotate` mixin out of the anime and IPTV hero carousels' duplicated `PageController` + auto-rotate `Timer` bookkeeping (pause-on-hover, advance-on-interval, dispose). Left height formulas, arrow-button styling, and desktop-detection strategy alone -- those are genuine per-carousel design differences, not copy-paste duplication -- and kept rotation interval/animation duration/curve as caller-supplied parameters so each carousel's exact existing feel was preserved.
- Extracted `SectionedHubScaffold` out of `MediaHub`/`BooksHub`'s identical `Scaffold > Column[SectionTopBar(), Expanded(section)]` shell + `HubController` listener wiring. Left `MusicHub`/`music_page.dart` alone -- its body is a `Stack` carrying ambient background glow, a keyboard listener, and drawer/modal overlays, a genuinely different shape, not a copy of this one -- and fixed `MusicHub`'s doc comment, which still described a sidebar/bottom-nav layout removed earlier this session.

### Player
- Trimmed the player down to standard controls: removed the Stop button from the bottom play bar and the Shuffle toggle from the expanded music player, added a volume slider (there was previously no volume UI at all, only a keyboard mute shortcut) in Shuffle's old spot. Previous/Play-Pause/Next/Repeat unchanged.
- True-centered the Watch/Listen/Read tabs in the top bar (`Stack` with the logo pinned left, tabs centered via `Center()`, Settings pinned right) -- they previously sat wherever a `Spacer()` pushed them, off-center relative to the window.
- **Search integrated into Music** instead of sitting as its own chip among content categories in the Listen hub's section bar. Music's search stays inline (its own tab/text field, not a pushed page like other hubs) -- only how you reach it changed, via a search icon next to the section bar.

### Navigation — global top bar + section chip bar
- Added a slim global **TopBar** (logo + **Watch / Listen / Read** hub switcher + a **Settings** button) pinned to the top of the window, so the app icon stays visible on every hub.
- **Removed the per-hub left sidebars** (Media, Books, Music) — they duplicated the section chip bar. Section switching is now done entirely by the **Section top bar** (horizontal chips) under the TopBar.
- Hubs renamed to verbs: **Watch** (Movies, Series, Anime, Genres, Library), **Listen** (Music, Search, Genres, Radio, Audiobooks, Library), **Read** (Manga, Comics, Library).
- **Audiobooks** moved from Read into Listen; the Listen chip order is Music, Search, Genres, Radio, Audiobooks, Library.
- The Listen home section is **Music**, so it reads cleanly as **Listen › Music** (matching **Watch › Movies**).
- **Removed the mobile bottom section-navs** (Media, Books, Music) — the global TopBar + Section chip bar now substitute them on all screen sizes.
- Added a **Section chip bar** — a horizontal bar at the top of every hub's content area for switching sections.
- Search is **per-page/scoped**: Movies/Series, Genres, Manga, Anime, Music, and Audiobooks each own a scoped search entry point; Music also gained a real search field.
- Movies and **Series now show different, correctly-typed content** (item type from addon, falling back to the catalog type, filtered on read).
- Fixes: Anime back button, no stray back buttons on top-level sections, consistent detail-page behavior (inline via nested navigator), consistent player expand/fullscreen.

### Navigation & Hub Architecture
- Shared TopBar + AppDock hosted in a single HubPage container (IndexedStack).
- Restructured to 3 content hubs — Media (Movies/Series/Anime), Books (Audiobooks/Manga), Music — each with a left sidebar and contextual collection.
- Settings moved to the TopBar gear icon (no longer a dock hub).
- TV D-pad keyboard navigation: arrow keys move focus between hubs, Enter/Space activates, visible focus ring.
- TV remote Back/Exit (Escape) pops the current route.
- TopBar and AppDock hidden during the intro splash.
- Back button on hub pages returns to the primary "Movies & Series" hub (no black screen).

### Player
- Volume & brightness swipe gestures: vertical swipe on left half = volume, right half = brightness, with on-screen indicator.
- Auto-Next Episode dialog: end-of-credits detection, 10s countdown, Play Next / Cancel, auto-play next episode.
- New PlayerSettings service with persisted Auto-Play Next toggle in Settings.
- Keyboard focus management: Space = play/pause, arrows = seek, M = mute, F = aspect, Esc = back.
- Screen-reader (Semantics) labels on all player control buttons.
- **Live progress bar** in the bottom play bar (Listen) and the expanded now-playing player (progress/seek stay in sync during playback).

### Collection & Services
- Unified Collection hub consolidating My List, Watchlist, History, and Downloads.
- Debrid integration (Real-Debrid, Torbox) with token verification in Settings.
- Download service with persistent queued state.
- Playback history service for continue-watching.
- Rich cast & crew with TMDB headshots.
- Trakt scrobbling and sync.

### Desktop
- Minimum window size enforced on Windows and macOS to prevent layout collapse.

### Playback Coordination
- New global `PlaybackCoordinator` ensures only one source plays at a time across music, video, and audiobooks — starting any playback stops the others.

### Global Shortcuts
- Music transport shortcuts (Space/K, J, L, M) now work app-wide via a new `GlobalShortcuts` wrapper, not just inside the Music page.

### Media Hub
- New **Genres** section in the Media sidebar aggregates genres from all active addons and lets you browse by genre.

### Search
- Search is now scoped to the currently selected section (Movies, Series, Anime, etc.) via a `SearchScope` registry, with a scoped hint and empty-state label.

### TV / Remote
- Pressing **Tab** focuses the bottom dock from anywhere, giving TV remotes an easy way to reach the hub switcher without scrolling through content.

### Navigation & Library
- Bottom dock reordered to **Media – Music – Books**.
- "My Collection" renamed to **Library** across hubs.
- Books hub now has its own **Library** showing liked manga and liked audiobooks.
- Like buttons added to manga and audiobook detail pages (persisted locally).
- Escape no longer pops the root HubPage (prevents black screen); it only pops when a route exists.
- Music album/playlist/artist modals now reflect live play/pause state on their play buttons and track rows.

### Universal Play Bar
- New **universal play bar** shown across all three hubs (Media, Books, Music) above the dock.
- Reflects whatever is currently playing (music, video, or audiobook) with cover, title, subtitle, play/pause, and stop controls.
- Tapping the bar expands the full music player; the Music page's old floating mini-player was removed to avoid duplication.

### Navigation & Search Polish
- Music sidebar title no longer hidden behind the shared TopBar (added top padding).
- Music sidebar/mobile nav now clears active search when switching tabs, so Browse/Radio/Library actually navigate (previously the search view blocked them).
- TopBar search placeholder is now dynamic per section (e.g. "Search Movies...", "Search Music...").
- Audiobooks section no longer shows its own title/search bar (search is handled by the parent section).
- Genres page filters out year-like entries (e.g. "2024") so only real genres are shown.
- New shared `LibraryTabs` component; Books Library now uses it with Manga / Audiobooks / History tabs.

### Unified Header & Navigation
- Replaced the logo + search-bar TopBar with a new **AppHeader**: three hub buttons (Media / Music / Books), a section dropdown, a search icon, and a settings icon.
- Removed the PlayTorrio logo/name from the header; the active section name is shown via the dropdown.
- Removed the per-hub mobile bottom navs (Media, Books, Music); section switching now happens in the header dropdown.
- Added a shared `HubController` so the header, sidebars, and hubs stay in sync.
- Repositioned the bottom dock: on mobile it appears at the top (below the header); on desktop it stays at the bottom, offset right so it never overlaps the left sidebar.
- ROADMAP updated: removed completed tasks, added full liquid-glass theming as a future task.

### Header Refinement
- Restored the **PlayTorrio logo + name** at the top left of the header.
- Removed the section dropdown from the header (sections are switched via the left sidebar).
- Removed the old bottom dock entirely; hub switching is now done via the header hub buttons.
- Search is now an **input bar** in the header, next to the hub buttons.
- Page content now renders inside a dedicated box between the header and the left panel, so it never overlaps either.

### Cleanup & Responsive Header
- Removed unused `AppDock` and `LiquidDock` widgets; moved the `AppHub` enum to its own file.
- Fixed the extra black gap on the left (content no longer double-offsets past the hub's own sidebar).
- Restored mobile bottom section navs for Media, Books, and Music.
- Books Library tabs reordered to **Audiobooks, Manga, History**.
- Header is now responsive: on mobile it shows an icon logo, a hub dropdown, and a search icon; on desktop it shows the full logo, hub buttons, and a search input bar.

### Inline Detail Pages & Cleanup
- Removed the per-page search/settings headers from the Music page (now covered by the global header).
- Added a **Shortcuts** button to the Media and Books left sidebars (Music already had one).
- Each hub now runs in its own nested `Navigator`, so detail pages (movies, artists, albums, manga, etc.) render **inside the content area** — keeping the left sidebar and top header visible — instead of taking over the full screen or appearing as popups.
- Fullscreen playback (video, book, song with cover) still uses the root navigator as before.

### Music Library & Play Bar
- Music Library now uses the shared `LibraryTabs` design with **Liked Songs / Playlists / Recent** tabs, matching the Media and Books libraries.
- Universal play bar repositioned: on desktop it sits above the bottom offset right of the left sidebar; on mobile it sits above the bottom section nav (no overlap).
- Added a **close** button to the universal play bar (dismisses the bar without stopping playback).
- Fullscreen playback (video player, audiobook player, manga reader) now explicitly uses the root navigator so it opens fullscreen only when actually inside the content.

### Background Audiobook Playback
- Audiobooks now start playing in the **background** from the detail page and "continue listening" — the bottom play bar appears instead of a fullscreen player.
- Tapping the bottom play bar opens the fullscreen audiobook player.
- Added a singleton `AudiobookPlayerController` for background playback.
- Single-source playback is enforced app-wide via the `PlaybackCoordinator` (never multiple audios/videos at once).

### Inline Detail Pages & Cleanup
- Anime details now render **inside the content box** (maintaining the lateral panel) instead of as a centered popup.
- Removed the anime page's internal logo/search/settings header (now covered by the global header).
- Movies and Series sections now set the correct content type on each item, so series are treated as series (not movies).

## [0.0.2] — 2026-08-11

### Added
- Stremio-compatible addon protocol with catalog browsing, search, and metadata enrichment
- 9 VOD stream scrapers (FlyStream, Videasy, VidSrc, MultiEmbed, VidCore, 4KHDHub, XDownloader, Knaben, TorrentGalaxy)
- Native libtorrent streaming engine with intelligent file selection and real-time stats
- 9-source audiobook aggregator with torrent and direct streaming support
- WeebCentral manga reader with horizontal/vertical modes, zoom, and progress tracking
- Octave music streaming with library management, playlists, and keyboard shortcuts
- Subdl subtitle download and extraction with multi-language support
- Glassmorphism UI system with GPU shader effects and performance fallback toggle
- Custom route transitions (LiquidRevealRoute, CinematicSlideRoute)
- Responsive card layout adapting to phone, tablet, and desktop widths
- macOS-style liquid dock navigation
- 5-platform support (iOS, macOS, Android, Linux, Windows)
- Audiobook sleep timer and variable playback speed
- "More Like This" recommendations via BestSimilar scraper
- Search relevance scoring with exact-match-first ranking
- Progressive content loading across all sections