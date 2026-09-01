# Project Roadmap — PlayTorrioMod

What is **outstanding**. Shipped work lives in [`CHANGELOG.md`](CHANGELOG.md);
this file stays about what is left.

Last reconciled against the tree: **2026-08-31** (v1.1.3+11, dev channel,
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

**Open decision carried over from the fork, not yet resolved either here or
there:** PlayTorrioMov's fork work found that removing the Music/Books
hubs also deleted `MediaSessionService` — which turned out to be generic
(mirrors `PlaybackCoordinator` for any source, not Music-specific), so
video playback on Android/iOS lost its lock-screen/notification/Bluetooth
media controls in that fork. This repo (PlayTorrioMod) is unaffected — it
kept the service. Worth deciding whether PlayTorrioMov should get it back
(re-adds the `audio_service` dependency and a background-audio permission)
or stay without it as a documented trade-off.

## Navigation principle

Three top-level hubs are the core navigation: **Watch**, **Listen**, **Read**.
Each has exactly four sections, the fourth always being Library:

| Hub    | Sections                                    |
|:-------|:--------------------------------------------|
| Watch  | Movies & Series · Anime · Live TV · Library |
| Listen | Music · Podcasts · Radio · Library          |
| Read   | Audiobooks · Books · Comics/Manga · Library |

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

Once a build has actually been through this, clear `AppInfo.channel` and the
`(dev)` marker disappears from the app and from release titles.

## Code and consistency

| # | Task                                                                                              | Why it is still open                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
|---|---------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 5 | **Anime and Movies/Series now share one row; the pages still differ**                             | The row is done: `BrowseRowView` is the single implementation, `BrowseScaffold` builds its rows from it and `AnimeSliderSection` wraps it, so card size, spacing, header and arrows cannot drift. Migrating the anime *page* itself onto `BrowseScaffold` was **dropped as not worth it**: `AnimeSliderSection` is also used by `anime_search_page`, so converting only the anime page would leave two row implementations on adjacent screens — worse than before. Converting both is two large pages of churn for a layout that now already matches. What the anime page still has of its own is a hero carousel and a `ContinueWatchingSlider` slot; revisit only if a third page wants that arrangement. |
| 6 | **35 files do ad-hoc `MediaQuery.sizeOf(context).width`** instead of `AppBreakpoints.of(context)` | 35 independent call sites, no shared risk, no user-visible bug. Migrate opportunistically when a file is touched for another reason, not as a batch pass.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 7 | **`music_page.dart` is 5,220 lines**                                                              | Four other files are over 2,000. Splitting is worthwhile but is a refactor with no user-visible payoff, so it waits behind anything that a user would notice.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| 8 | **Kotlin Gradle Plugin will break future Flutter builds**                                         | Every Android build warns: the app and six plugins (`package_info_plus`, `shared_preferences_android`, `torrserver_flutter`, `url_launcher_android`, `video_player_android`, `wakelock_plus`) apply KGP, and *"future versions of Flutter will fail to build if your app uses plugins that apply KGP"*. The app's own `build.gradle.kts` can migrate to Built-in Kotlin; the plugins cannot be fixed here — each needs a version that supports it, or an upstream issue. Not urgent, but it is a dated fuse rather than a style nit.                                                                                                                                                                         |

## Known bugs

| #  | Bug                                             | Notes                                                                                                                                                                                                                    |
|----|--------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 12 | **"Unknown hard error" on Windows after closing the app** | Reported 2026-08-31. Not yet reproduced/triaged — need a stack trace or exact repro steps (does it happen on every close, or only after specific actions like an active torrent/stream? does it show a dialog or just appear in Event Viewer?) before this can be root-caused. |

## Requested UI work

| #  | Task                                                              | Notes                                                                                                                                                                                                                                                                    |
|----|--------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 13 | **Icon-button consistency, plus a Watchlist/Watched pair** | Requested 2026-08-31. The heart/like icon (`LikeButton`, `lib/widgets/common/like_button.dart`) is already unified across Music/Manga/Podcasts/Books (see its own doc comment). What's being asked now is broader: audit every content-action icon button (like, add-to-library/bookmark, watchlist, watched) for one consistent visual language, and add a distinct Watchlist ("plan to watch") vs. Watched (completed) pair for Movies/Series — today Movies/Series only has the single "Add to Library" bookmark toggle (deliberately not the heart, per `LikeButton`'s own doc comment), while Anime already has a four-state picker (Watching/Plan to Watch/Completed/Dropped). Needs a short design pass before implementation: is Watchlist/Watched a third state bolted onto the existing Library bookmark, or a separate concept end-to-end (its own storage, its own icon row)? |
| 14 | **Remove A-Z title sort on Movies/Series**  | Requested 2026-08-31. Find the sort control on `TypeCatalogPage`/`FilterDropdown` (movie/series catalogs) and drop the alphabetical option, keeping whatever the remaining sort choices are (e.g. popularity, release date, added date). |
| 15 | **Header space consistency between "Live TV" and "Movies & Series"** | Requested 2026-08-31. The two sections apparently don't share identical header/app-bar spacing or layout today. Needs a side-by-side comparison of both pages' header widgets before deciding whether to extract a shared header component or just align paddings/sizes independently. |
| 16 | **Settings icon: pin to top-right, always visible** | Requested 2026-08-31, clarified same day: fixed to the top-right of the persistent `TopBar`/mobile header, on every breakpoint. Hub names stay Watch/Listen/Read (asked, then declined — no rename after all). Small on its own; bundle with item 17 below since both change the same settings entry point. |
| 17 | **Opening Settings must not hide the three hub categories, on any breakpoint** | Requested 2026-08-31. Today it does: `HubPage` opens Settings via `Navigator.push(..., LiquidRevealRoute(page: const SettingsPage()))`, a full-screen route that covers the persistent `TopBar`/hub-pills and the mobile bottom bar entirely — true on mobile, tablet, desktop and (untested) TV alike, since it's the same push regardless of `AppBreakpoints.of(context)`. Making Settings coexist with the nav chrome instead (an overlay panel, a split view, a sheet that leaves the hub switcher reachable) is a real architecture change to `HubPage`'s settings entry point and possibly `SettingsPage`'s own `Scaffold`, not a one-line fix — needs its own design pass across all four breakpoints before implementation, TV especially since D-pad focus would need to move between the panel and the nav chrome. Both this and item 16 land together: the icon's new fixed position only matters once opening it no longer takes over the screen. |

## Content sources

| #  | Task                           | State                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
|----|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 9  | **Read hub is EPUB-only**      | Upstream has PDF, MOBI and FB2 readers (`pdfrx`, `dart_mobi`, `fb2_parse`) under `lib/pages/books/`; this fork's Read hub has one EPUB reader, and `BooksService._parseResults` drops every libgen row whose format is not `epub`. Restoring the other three means porting the reader pages *and* widening that filter — a feature port, not a merge. Found during the v1.0.8 merge (2026-08-31).                                                                                                                                                                 |
| 10 | **Comics data source**         | `ComicsPage` is an honest empty state, not a placeholder pretending to load. Two leads checked 2026-08-29: `newcomic.info` routes every `.cbr` through `florenfile.com` behind Cloudflare's JS challenge — dead for a server-side fetch. `readcomicsonline.lol` looks structurally right (own CDN, direct `.webp` per page, no archive extraction, same shape as Manga) but its chapter/page data loads client-side and the underlying endpoint did not surface from its JS bundles. Confirming it needs live devtools inspection by a human, not blind guessing. |
| 11 | **Cast photos for Audiobooks** | Movies/Series, Anime and Manga all have them. Audiobooks stays blocked: AniList does not catalog narrators, and AudiobookBay's listing HTML has no narrator field beyond free text. Would need a narrator-photo database that does not appear to exist publicly.                                                                                                                                                                                                                                                                                                  |

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

- **Android release signing needs two repository secrets** — `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`. Until they exist, every build is signed with a throwaway debug key, which means each new APK refuses to install over the last one and the in-app updater cannot work. See [release signing](configuration.md#release-signing). The keystore must be generated locally: it is a long-lived credential and should not pass through a chat transcript or CI logs.
- **No other platform needs signing for updates**, because none of them self-install. See the table in `configuration.md`.

## Declined, so they do not get re-litigated

- **A drawer for mobile hub switching.** Hub pills in the header plus the bottom section bar already cover every width. A drawer would be a third copy of the same control.
- **A unified hub+submenu component.** The header and section bars already read as one stacked unit. The only trigger to reopen is mobile's stacked chrome becoming an actual complaint.
- **Forcing all four playback controllers onto one `PlaybackCoordinator` contract.** Costs a real adapter per controller type to save two duplicated lines, with no current bug. Revisit if a fifth playback type forgets the sync.
- **`interneto/tv-multiview`'s channel data.** No stated license, no direct-stream-URL field, ~88 mostly-minor channels. IPTV multi-view shipped as an original grid feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is a namespace, not an identifier anything outside the module sees.
- **Putting Books on `BrowseScaffold`.** Checked 2026-08-30: `BookResult` carries no cover URL at all — libgen's list view does not expose one — so a hero and poster rows would render as blank rectangles. The current text-row list is the right layout for cover-less metadata. Reopen only if a cover source appears.
- **Replacing Manga's grid with `BrowseScaffold`'s rows.** Manga's grid is infinite-scrolling and its card density is a user setting (`MangaSettings.cardDensity`, with a customizer sheet). Fixed-length rows would remove both. Manga could gain a hero *above* its grid, which is a separate and much smaller change.
