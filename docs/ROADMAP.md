# Project Roadmap — PlayTorrioMod

What is **outstanding**. Shipped work lives in [`CHANGELOG.md`](CHANGELOG.md);
this file stays about what is left.

Last reconciled against the tree: **2026-09-02** (v1.1.3+11, dev channel,
level with upstream @ `41a11f4` / v1.0.9).

## Sibling app: PlayTorrioMov

`MediaHub-Org/PlayTorrioMov` is a Media-only fork of this repo (Movies &
Series, Anime, Live TV, Library — no Music, no Books) for users who already
have dedicated apps for music and reading. This repo (PlayTorrioMod) stays
the primary development target and keeps tracking upstream as above;
PlayTorrioMov gets Media-domain changes ported over manually, since its nav
was collapsed from three hubs to one and no longer matches this repo's
structure 1:1. See `PlayTorrioMov`'s own `docs/superpowers/specs/` for the
fork's design rationale.

**Resolved 2026-09-01:** PlayTorrioMov's fork work had found that removing
the Music/Books hubs also deleted `MediaSessionService` — generic
infrastructure (mirrors `PlaybackCoordinator` for any source, not
Music-specific) whose loss cost video its Android/iOS lock-screen,
notification and Bluetooth controls for no reason tied to the actual fork
goal. Restored it there — `audio_service` dependency, the service file,
the Android manifest entries, iOS's `audio` background mode. This repo
was never affected (kept the service throughout).

## Navigation principle

Three top-level hubs are the core navigation: **Watch**, **Listen**, **Read**.
Each has exactly four sections, the fourth always being Library:

| Hub    | Sections                                      |
|:-------|:----------------------------------------------|
| Watch  | Movies & Series · Anime · Live TV · Library   |
| Listen | Music · Podcasts · Radio · Library            |
| Read   | Audiobooks · Books · Comics & Manga · Library |

Phones show hubs as icon pills in the header and sections in the bottom bar;
tablet and desktop show sections as a chip row instead. Search, filters,
favourites and playback stay consistent across every section — that
cross-cutting consistency is what "unified" means here, not the content.

Any proposal to merge, flatten or collapse distinct content-type sections, or
to make one hub have a different number of sections than the others, should be
checked against this first.

## Blocked on a device

Nothing in this group can be closed from CI. Every item is implemented and
passing `flutter analyze` + the test suite; none has been run on hardware.

| # | Area                                   | What specifically needs checking                                                                                                                                                                                                                                                                          |
|---|----------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | **Media session** (shipped 2026-08-30) | Track title/artist/art in the Android shade; play/pause/skip/stop; audio surviving backgrounding; whether tapping the notification returns to the running app rather than restarting it. iOS lock screen and Control Center likewise.                                                                     |
| 2 | **media_kit/libmpv playback**          | The engine swap (2026-08-28) changed torrent streaming, live IPTV, subtitle rendering, decoder presets and the volume-boost gesture. Needs a hands-on pass across movie / series / anime / IPTV / music / audiobook. The `mediacodec-copy` fix for the Android black screen (2026-08-29) is part of this. |
| 3 | **Resume across sources**              | `ContinueWatchingService` absorbed `PlaybackHistoryService`. Resume across movie / series / anime / torrent paths is unconfirmed on a device.                                                                                                                                                             |
| 4 | **QA on all five platforms**           | Mobile, tablet, desktop, TV. TV needs its own D-pad/remote-input pass. Most work to date has only been exercised on Windows desktop and in CI.                                                                                                                                                            |

**`AppInfo.channel` was cleared 2026-09-02** ahead of this checklist, by
product decision after a full multi-platform CI build passed — the `(dev)`
marker no longer gates on these items, but they stay open and worth actually
checking on hardware when possible.

## Code and consistency

| # | Task                                                                                              | Why it is still open                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|---|---------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 6 | **35 files do ad-hoc `MediaQuery.sizeOf(context).width`** instead of `AppBreakpoints.of(context)` | Checked 2026-09-01: many are legitimate geometry math (player scrubber positions, card-size ratios), not nav-tier decisions — a blind batch conversion risks real regressions with no way to visually verify 35 files' worth of layout changes. Migrate opportunistically when a file is touched for another reason, not as a batch pass.                                                                                                                                                                                            |
| 7 | **`music_page.dart` is 5,220 lines**                                                              | Four other files are over 2,000. Splitting is worthwhile but is a refactor with no user-visible payoff, so it waits behind anything that a user would notice.                                                                                                                                                                                                                                                                                                                                                                        |
| 8 | **Kotlin Gradle Plugin will break future Flutter builds**                                         | Every Android build warns: the app and six plugins (`package_info_plus`, `shared_preferences_android`, `torrserver_flutter`, `url_launcher_android`, `video_player_android`, `wakelock_plus`) apply KGP, and *"future versions of Flutter will fail to build if your app uses plugins that apply KGP"*. The app's own `build.gradle.kts` can migrate to Built-in Kotlin; the plugins cannot be fixed here — each needs a version that supports it, or an upstream issue. Not urgent, but it is a dated fuse rather than a style nit. |

## Content sources

| #  | Task                           | State                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
|----|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 9  | **Read hub is EPUB-only**      | Upstream has PDF, MOBI and FB2 readers (`pdfrx`, `dart_mobi`, `fb2_parse`) under `lib/pages/books/`; this fork's Read hub has one EPUB reader, and `BooksService._parseResults` drops every libgen row whose format is not `epub`. Restoring the other three means porting the reader pages *and* widening that filter — a feature port, not a merge. Found during the v1.0.8 merge (2026-08-31).                                                                                                                                                                 |
| 10 | **Comics data source**         | `ComicsPage` is an honest empty state, not a placeholder pretending to load. Two leads checked 2026-08-29: `newcomic.info` routes every `.cbr` through `florenfile.com` behind Cloudflare's JS challenge — dead for a server-side fetch. `readcomicsonline.lol` looks structurally right (own CDN, direct `.webp` per page, no archive extraction, same shape as Manga) but its chapter/page data loads client-side and the underlying endpoint did not surface from its JS bundles. Confirming it needs live devtools inspection by a human, not blind guessing. |
| 11 | **Cast photos for Audiobooks** | Movies/Series, Anime and Manga all have them. Audiobooks stays blocked: AniList does not catalog narrators, and AudiobookBay's listing HTML has no narrator field beyond free text. Would need a narrator-photo database that does not appear to exist publicly.                                                                                                                                                                                                                                                                                                  |

## Known bugs

| #  | Bug                                                       | Notes                                                                                                                                                                                                                                                                          |
|----|-----------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 12 | **"Unknown hard error" on Windows after closing the app** | Reported 2026-08-31. Not yet reproduced/triaged — need a stack trace or exact repro steps (does it happen on every close, or only after specific actions like an active torrent/stream? does it show a dialog or just appear in Event Viewer?) before this can be root-caused. |

## Requested UI work

| #  | Task                                                                                         | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|----|----------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 13 | **Hero carousel image quality/cropping — Live TV still open** | Requested 2026-09-01. Movies & Series and Anime shipped 2026-09-02 (see `CHANGELOG.md`). **Live TV** (`iptv_hero_carousel.dart:234-238`) already uses a proper `channel.backdropUrl` with `BoxFit.cover` — the code shape looks right, so the reported cropping/low-res is more likely either the source images themselves being low-res, or the crop region disagreeing with `BoxFit.cover`'s centring for these specific images; needs an actual look at the rendered carousel on a device, not a code-only fix. |
| 14 | **Books, Podcast, Music on the same UX/UI as Anime** | Requested 2026-09-01, investigated same day. Radio's actual bug (fake genre search instead of real stations) shipped 2026-09-02 — see `CHANGELOG.md`. What's left is purely cosmetic: Music/Podcasts/Radio all live inside `music_page.dart`'s own bespoke `Stack`-based layout (ambient background, custom tab switching) rather than `BrowseScaffold`'s hero+rows shape Anime uses — a deliberate divergence per `sectioned_hub_scaffold.dart`'s own doc comment ("Music opts out... genuinely different shape"). Moving Music/Podcasts/Radio onto `BrowseScaffold` is a real redesign (new hero data per tab, row layout for a UI that's currently one continuous scroll) — worth confirming that's actually wanted before reworking a page that already opted out on purpose. Books has its own separate blocker (see Declined section below): `BookResult` carries no cover URL at all, so a hero/rows layout would render blank regardless. |
| 15 | **Movies & Series header: drop the redundant title, move Genre/Decade/Sort next to search like Anime** | Requested 2026-09-02, investigated same day. `type_catalog_page.dart:239-250`: a 28px `widget.title` ("Movies" or "Series") sits above the hero, duplicating what the Watch section pill/bottom-bar tab already says. Same file, lines 252-303: the Genre/Decade/Sort `FilterDropdown`s sit in a `Wrap` *below* that title row — Anime puts its equivalent dropdowns in a `Positioned` row at top-right next to the search icon (`anime_page.dart:563-593`, fixed this session for the language dropdown). Dropping the title frees that space; moving the three dropdowns up to Anime's position is the natural next step, not a separate layout. |
| 16 | **Hero carousels: bigger, closer to the original app's sizing** | Requested 2026-09-02, investigated same day. `BrowseScaffold._heroHeight` (`browse_scaffold.dart:125-129`) is flat and width-only: 240 / 320 / 420px, no screen-height factor at all — Movies & Series and every other `BrowseScaffold` consumer inherits this. For comparison, upstream's own pre-fork hero (`anime_hero_spotlight.dart:67` on `ayman708-UX/PlayTorrioV3`) used `320` fixed on mobile and `(screenHeight * 0.60).clamp(440, 680)` on desktop — up to 680px, well over this fork's 420px cap, and height-relative like Anime's own carousel already is post-item-13. Likely fix shape: give `BrowseScaffold._heroHeight` the same screen-height-relative treatment Anime and Live TV already have, sized in that 440–680 range rather than the current 240–420. |
| 17 | **Newest/Oldest sort pill does nothing in the default view** | Requested 2026-09-02, root-caused same day — a real bug. `type_catalog_page.dart:196-223`: with no genre/decade filter active (`_isFiltered == false`, the default), the page renders `_sections` as rows through `BrowseScaffold` directly — `_sort` is never consulted. `_sort` only affects anything inside `_visibleItems` (line 56-69), which only the *filtered grid* branch reads. So tapping Newest/Oldest visibly does nothing unless a genre or decade is already picked. Separately, even when it does apply, the comparator sorts by `_decadeOf()` (year rounded down to the decade, line 62-67) rather than by actual year, so two titles in the same decade never reorder against each other — coarser than "Newest/Oldest" implies. Two bugs, same feature: wire `_sort` into the unfiltered rows view too (or hide the pill until a filter is active), and compare actual parsed years instead of decade buckets. |
| 18 | **Library Saved: a type filter (Movies/Series/Anime), separate from Liked/Watchlist** | Requested 2026-09-02, investigated same day — bigger than it first looked. `collection_page.dart`'s Saved tab (the `_StatusChip` pair added this session for item 22) only filters by *status* (Liked vs. Watchlist) within `MyListService.items` (`List<MyListItem>`). A Movies-vs-Series split on that list is trivial — `MyListItem.type` already holds `'movie'` or `'series'`. **Anime is not in scope for that split at all**: `MyListItem.fromMovie`/`fromMovieDetail` (`my_list_item.dart:110,135`) collapse `type: 'anime'` into `'series'` on construction, and in practice Anime never even reaches this — it has its own entirely separate `AnimeLibraryService`/`AnimeWatchStatus` four-state system (`anime_library_service.dart`), never `MyListService`. So Watch's shared Saved tab has never shown anime at all. A real "Movies/Series/Anime" filter means either merging Anime's separate store into the shared Saved tab (a real data-model unification, `AnimeWatchStatus` doesn't map cleanly onto Liked/Watchlist's two states), or the request is narrower than it sounds and just means Movies-vs-Series. Needs a decision — see questions below. |
| 19 | **Podcasts needs its own hero+rows page** | Requested 2026-09-02, sharpens item 14 above. Currently `PodcastsPage()` (`music_page.dart:1013`, routed in when `_activeTab == 'Podcasts'`) rather than anything `BrowseScaffold`-shaped — same underlying ask as item 14, called out specifically for Podcasts this time. Folding into item 14's scope rather than tracked twice. |
| 20 | **Song rows: swap the inline Download icon for a Like icon** | Requested 2026-09-02, investigated same day. `_MusicTrackRow` (`music_page.dart:2726-2814`) shows `MusicTrackDownloadButton` inline plus a "..." button. The "..." menu (`_showAddToPlaylistMenu`, `music_page.dart:560` onward) **already has** a download quick-action (line 641-700) *and* a "Save to Playlist" section with an inline "New Playlist" create action (line 701 onward, playlist list presumably below) — so download is already reachable from there, making the row's own download icon a second, redundant entry point for the same action. No inline Like exists anywhere on the row today. Likely fix: drop the row's `MusicTrackDownloadButton`, add a heart/like icon in its place, leave download as the "..." menu's job alone — which also directly satisfies the separately-requested "three-dot menu: playlist pick/create, download inside that" (item 8, shipped 2026-09-02) since that menu already has both. |
| 21 | **"New Playlist" should only show inside Saved/Playlists, not on every Listen tab** | Requested 2026-09-02 — a correction to this session's own item 24 (shipped 2026-09-02), which moved "New Playlist" into the persistent 44px toolbar shown across *every* Listen sub-tab (`music_page.dart:890-912`, see its own comment explaining that choice). Now asked to scope it back down to only the Saved tab's Playlists sub-view. Needs a decision — see questions below. |
| 22 | **Settings icon visually collides with the hub tabs on narrower desktop/tablet widths** | Requested 2026-09-02, root-caused same day. `TopBar.build` (`top_bar.dart:44-67`) lays the hub-switcher out with a bare `Center` inside a `Stack`, centered on the *full* bar width — it does not reserve space for `SidebarLogo` on the left or the settings `IconButton` on the right (both placed via `Align`, which doesn't shrink the `Center` content to fit between them). As the window narrows, the truly-centered hub tabs can grow into the same region as the settings button, reading as the button being "displaced" even though its own `Align` position never moves. Mobile's `_MobileTopBar` (`adaptive_nav_shell.dart:77-108`) uses a real `Row` with `Flexible`/`Spacer` and does not have this problem — the desktop/tablet `TopBar` needs the same treatment (`Row` with `Expanded`/`Flexible` sections instead of `Stack`+`Center`). |
| 23 | **No minimum window size on desktop** | Requested 2026-09-02, confirmed same day: no call to `window_manager`'s `setMinimumSize` (or equivalent) exists anywhere in `lib/services/window/window_service.dart` or the native Windows runner — the window can be resized arbitrarily small, well below anything the phone-tier layout was designed for. Needs a floor; exact dimensions are a product call (see questions below). |
| 24 | **Music player: seekbar is tap-only, no drag-to-scrub; play/pause "needs improvement"** | Requested 2026-09-02, partially root-caused same day. `MusicWaveformSeekbar` (`music_waveform_seekbar.dart`) wires `onTapDown` for seeking in all three of its variants (lines 125, 188, 244, 270) but has no `onPanUpdate`/`onHorizontalDragUpdate` handler anywhere in the file — dragging along the bar does not scrub, only a fresh tap does, which reads as broken/imprecise next to an ordinary `Slider`. The play/pause half of the complaint has no matching concrete defect found yet (`universal_play_bar.dart`'s button wiring looks ordinary) — needs specifics before there's anything to fix. See questions below. |


## Staying level with upstream

The fork tracks `ayman708-UX/PlayTorrioV3`. As of 2026-08-31 it is **zero
commits behind** (`upstream/main` @ `41a11f4`, v1.0.9).

Merging upstream is not a `git merge` and a green analyzer — the last two syncs
both had real breakage in regions git's 3-way diff never flagged, because only
one side had touched them. The routine that catches it:

1. `git merge upstream/main --no-commit`, then resolve.
2. Identity files always resolve to ours: `pubspec.yaml` version,
   `build.gradle.kts`, the two `project.pbxproj`, `AppInfo.xcconfig`,
   `CMakeLists.txt`, `Runner.rc`, `setup.iss`, `build.yml`.
3. Read `docs/FORK_DIFFERENCES.md` § *Deliberate divergences* and confirm each
   one survived — they are exactly what a merge silently reverts.
4. Grep for this fork's landmark fixes: `mediacodec-copy`,
   `MediaSessionService.init`, `LibrarySection.values`, the namespaced
   `my_list_item` keys, `_buildFatalErrorView`.
5. Then `flutter analyze` and the suite.

## Signing and releases

- **Android release signing secrets are set** — `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD` both confirmed present on the GitHub repo 2026-09-01 (`gh secret list`, names only — values aren't retrievable, nor were they needed to be). Release builds should now sign with the real key instead of the throwaway debug one, so APKs should install over the previous version and the in-app updater should work. Not yet verified end-to-end with an actual release build — that needs a real CI run, not just confirming the secrets exist. See [release signing](configuration.md#release-signing).
- **No other platform needs signing for updates**, because none of them self-install. See the table in `configuration.md`.

## Declined, so they do not get re-litigated

- **A drawer for mobile hub switching.** Hub pills in the header plus the bottom section bar already cover every width. A drawer would be a third copy of the same control.
- **A unified hub+submenu component.** The header and section bars already read as one stacked unit. The only trigger to reopen is mobile's stacked chrome becoming an actual complaint.
- **Forcing all four playback controllers onto one `PlaybackCoordinator` contract.** Costs a real adapter per controller type to save two duplicated lines, with no current bug. Revisit if a fifth playback type forgets the sync.
- **`interneto/tv-multiview`'s channel data.** No stated license, no direct-stream-URL field, ~88 mostly-minor channels. IPTV multi-view shipped as an original grid feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is a namespace, not an identifier anything outside the module sees.
- **Putting Books on `BrowseScaffold`.** Checked 2026-08-30: `BookResult` carries no cover URL at all — libgen's list view does not expose one — so a hero and poster rows would render as blank rectangles. The current text-row list is the right layout for cover-less metadata. Reopen only if a cover source appears.
- **Replacing Manga's grid with `BrowseScaffold`'s rows.** Manga's grid is infinite-scrolling and its card density is a user setting (`MangaSettings.cardDensity`, with a customizer sheet). Fixed-length rows would remove both. Manga could gain a hero *above* its grid, which is a separate and much smaller change.
