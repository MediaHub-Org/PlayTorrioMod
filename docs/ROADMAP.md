# Project Roadmap — PlayTorrioMod

What is **outstanding**. Shipped work lives in [`CHANGELOG.md`](CHANGELOG.md);
this file stays about what is left.

Last reconciled against the tree: **2026-09-02** (v1.1.4, level with
upstream as of `68140b8` — see *Staying level with upstream* below).

## Sibling app: PlayTorrioMov

`MediaHub-Org/PlayTorrioMov` is a Media-only fork of this repo (Movies &
Series, Anime, Live TV, Library — no Music, no Books) for users who already
have dedicated apps for music and reading. This repo (PlayTorrioMod) stays
the primary development target and keeps tracking upstream as above;
PlayTorrioMov gets Media-domain changes ported over manually, since its nav
was collapsed from three hubs to one and no longer matches this repo's
structure 1:1. See `PlayTorrioMov`'s own `docs/superpowers/specs/` for the
fork's design rationale.

## Navigation principle

Three top-level hubs are the core navigation: **Watch**, **Listen**, **Read**.
Each has exactly four sections, the fourth always being Library:

| Hub    | Sections                                              |
|:-------|:-------------------------------------------------------|
| Watch  | Movies & Series · Anime · Live TV · Library             |
| Listen | Music · Podcasts/Audiobooks (sub-tab) · Radio · Library |
| Read   | Books · Comics · Manga · Library                        |

Audiobooks moved from Read to Listen 2026-09-02, paired with Podcasts behind
a sub-tab (`HubController.spokenAudioType`) — both are episodic spoken audio,
the same reasoning Movies/Series share one Watch section for. Comics and
Manga split from one shared "Comics & Manga" section into two independent
ones, backfilling the slot Audiobooks leaving freed up.

Phones show hubs as icon pills in the header and sections in the bottom bar;
tablet and desktop show sections as a chip row instead. Search, filters,
favorites and playback stay consistent across every section — that
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
| 2 | **media_kit/libmpv playback**          | The engine swap (2026-08-28) changed torrent streaming, live IPTV, subtitle rendering, decoder presets and the volume-boost gesture. Needs a hands-on pass across movie / series / anime / IPTV / music / audiobook. The `mediacodec-copy` fix for the Android black screen (2026-08-29) is part of this. `AudiobookPlayerController` (the background/mini-bar controller) joined this engine 2026-09-02 too — was the one holdout still on `video_player`; needs the same hands-on check as the rest. First real hands-on pass done 2026-09-02 (Windows, movie playback only): found and fixed two bugs (`UniversalPlayBar` showing over the full-screen video player; Continue Watching resume getting stuck re-buffering from a redundant seek) and reconfirmed #12 still crashes with active playback. Series/anime/IPTV/music/audiobook paths and every non-Windows platform remain unchecked. |
| 3 | **Resume across sources**              | `ContinueWatchingService` absorbed `PlaybackHistoryService`. Resume across movie / series / anime / torrent paths is unconfirmed on a device. Movie-path resume-from-history bug found and fixed 2026-09-02 (see item 2) — series/anime/torrent paths still unconfirmed.                                                                                                                                                             |
| 4 | **QA on all five platforms**           | Mobile, tablet, desktop, TV. TV needs its own D-pad/remote-input pass. Most work to date has only been exercised on Windows desktop and in CI.                                                                                                                                                            |

The `(dev)` channel marker no longer gates on this list (cleared 2026-09-02
by product decision) — these items stay open regardless, worth checking on
hardware when possible.

## Code and consistency

| # | Task                                                                                              | Why it is still open                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|---|---------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 7 | **`music_page.dart` is 6,579 lines** (grew from 5,220 on 2026-09-02, absorbing Audiobooks' Liked/In Progress/Downloads sub-tabs, then Radio's search/liking and the album/playlist play-button work, all the same day) | Four other files are over 2,000. Splitting is worthwhile but is a refactor with no user-visible payoff, so it waits behind anything that a user would notice.                                                                                                                                                                                                                                                                                                                                                                        |
| 8 | **Kotlin Gradle Plugin will break future Flutter builds** | Re-checked 2026-09-02: the app's own `settings.gradle.kts`/`build.gradle.kts` already match Flutter 3.44.0's own current app template exactly (`org.jetbrains.kotlin.android` declared with `apply false`, the current recommended shape) — there is no "migrate the app to Built-in Kotlin" step actually available here; that part of the original note didn't hold up. The real issue is six *plugins* independently applying KGP with their own `ext.kotlin_version`/`apply plugin: 'kotlin-android'` in their own `android/build.gradle`, which is what breaks under a future Flutter. `flutter pub upgrade` (same day) already fixed **3 of 6** as a side effect: `shared_preferences_android` (2.4.28), `url_launcher_android` (6.3.33) and `video_player_android` (2.12.2) now use the modern `kotlin { jvmTarget = ... }` block, confirmed by reading each one's `android/build.gradle` in the pub cache. Still on the old pattern: `package_info_plus` (8.3.1 — 10.2.1 exists but is a major bump past our `^8.3.1` constraint, unchecked for breaking API changes), `wakelock_plus` (1.3.3 — 1.8.0 exists and fits our `^1.3.3` constraint, but `flutter pub outdated` shows it's capped at 1.3.3 by some other package's transitive constraint, not ours to relax), `torrserver_flutter` (0.0.6, no newer version published yet). Down to 3 real blockers, none fixable by just editing our own pubspec. |

## Content sources

| #  | Task                           | State                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
|----|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 9  | **Read hub: MOBI/FB2 still unsupported** | PDF shipped 2026-09-02 (see `CHANGELOG.md`) — renders standalone via `pdfrx`, no shared parsing with the EPUB reader, so it was safely addable. MOBI/FB2 are a different shape of work: upstream normalizes both into the same chapter/HTML data the EPUB reader consumes, through a parser service (`dart_mobi`, `fb2_parse`) this fork never ported — real, riskier feature work touching the shared reader, not a drop-in like PDF was. Found during the v1.0.8 merge (2026-08-31). |
| 10 | **Comics data source**         | `ComicsPage` is an honest empty state, not a placeholder pretending to load. Two leads checked 2026-08-29: `newcomic.info` routes every `.cbr` through `florenfile.com` behind Cloudflare's JS challenge — dead for a server-side fetch. `readcomicsonline.lol` looks structurally right (own CDN, direct `.webp` per page, no archive extraction, same shape as Manga) but its chapter/page data loads client-side and the underlying endpoint did not surface from its JS bundles. Confirming it needs live devtools inspection by a human, not blind guessing. |

## Known bugs

| #  | Bug                                                       | Notes                                                                                                                                                                                                                                                                          |
|----|-----------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 12 | **"Unknown hard error" on Windows after closing the app** | Reported 2026-08-31. Candidate fix (`onShutdownDispose`, 2026-09-02) did **not** resolve it — reproduced live 2026-09-02 with an active 2160p stream playing (`PlayerScreen`) at close time: System Event Viewer logged the exact `PlayTorrioMod.exe - System Error : Unknown Hard Error` popup (Event ID 26, "Application Popup") at the moment of close, `flutter run`'s own log showed a clean `exited with code 0` and confirmed `VideoOutput::~VideoOutput` actually ran (the dispose hook fired as designed) — so the crash happens *after* Dart-side cleanup completes, at the native/OS layer, and isn't the undisposed-`Player` cause originally diagnosed. A same-session control run with **no** active playback closed clean with zero Event Viewer entries, so this is still specifically tied to an active video stream at close time, just not through the mechanism the candidate fix addressed — possibly a media_kit/D3D11 GPU resource (texture/render thread) racing process teardown even after `Player.dispose()` returns. No Application-log crash entry (Event 1000/WER) was generated alongside it, so no faulting module/stack is available from Event Viewer alone; would need a local crash dump (`LocalDumps` registry key, requires admin) or a native debugger attached at close to go further. Reopened — still open, root cause not yet found. |

## Requested UI work

Nothing outstanding here right now — item 13 (Movies/Series & Anime browse
page parity: hero image, Continue Watching, pill switcher, Latest
Releases/Calendar rows, consistent search UX across Listen/Read, the
Audiobooks/Podcasts nav restructure) shipped 2026-09-02; see `CHANGELOG.md`
for the full breakdown. Live TV's own hero (`iptv_hero_carousel.dart:234-238`)
was checked and already renders correctly in code — still worth an on-device
look, folded into item 4 below rather than tracked separately.

Still open, not part of that pass: **Continue Reading matching Continue
Watching's card style**, and Manga/Comics' own genre/type-selection matching
Movies & Series' pill row (`PillTabRow`/`SubTab`) — raised 2026-09-02, not
started. Books has no cover art (`BookResult` from libgen.li carries none,
see Declined below), so a literal `ContinueWatchingSlider`-style card would
show a fallback icon in place of art on every entry, not real backdrop
images.

Manga's own layout got a same-day reorder pass (title → genre pills/
customize/search in one row → Continue Reading → grid) that's a different,
narrower ask than the one above — repositioning, not restyling. Its genre
pills are still their own hand-built `AnimatedContainer` chips, not
`PillTabRow`; that's still what's meant by "matching Movies & Series' pill
row" above.

## Staying level with upstream

The fork tracks `ayman708-UX/PlayTorrioV3`. Merged 2026-09-02 up to
`upstream/main` @ `68140b8` ("Fix TorrServer and Debrid episode matching
engine with multi-episode and directory parsing") — level with upstream as
of that commit. See `CHANGELOG.md` for what the merge brought in and how
conflicts were resolved (this fork's hub architecture won on every one).

Merging upstream is not a `git merge` and a green analyzer — past syncs
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

**Resolved 2026-09-02.** The v1.1.4 release run confirmed real-key signing
end-to-end, not just secret presence: both Android jobs logged "Release
signing configured (alias: playtorriomod)" — the debug-key fallback path
(which only fires when the secrets are absent) never triggered. APKs from
here on install over the previous version; the in-app updater works. No
other platform needs signing for updates, since none of them self-install.
See [release signing](configuration.md#release-signing).

## Declined, so they do not get re-litigated

- **A blind batch conversion of the 35 files doing ad-hoc `MediaQuery.sizeOf(context).width`** instead of `AppBreakpoints.of(context)`. Checked 2026-09-01: many are legitimate geometry math (player scrubber positions, card-size ratios), not nav-tier decisions — converting all 35 in one pass risks real regressions with no way to visually verify that many layout changes at once. Migrate opportunistically when a file is touched for another reason instead — which is how several already got fixed this session (`type_catalog_page.dart`, `manga_reader_page.dart`) without a dedicated pass.
- **Folding `AnimeLibraryService` into `MyListService`.** Considered 2026-09-02 while closing out the Saved-tab Anime type filter (item 25's `isLiked` work surfaced this). Anime's own status picker has four states — Watching, Plan to Watch, Completed, Dropped; `MyListItem` has three flags shaped around Movies/Series — Watchlist, Watched, Liked. "Watching" and "Dropped" have no honest equivalent on either side; mapping them in would mean either lying about an anime's status to fit the wrong shape, or bolting a second state model onto `MyListItem` that only anime uses, which breaks the one-shape-three-hubs property the shared model exists for. Simkl-synced anime already shows correctly under the Saved tab's Anime chip (shipped 2026-09-02, typed via the sync bucket, not this local store) — that covers the case that actually reaches a shared list. Locally-tracked anime status stays in Anime's own pages, where its four states are the right shape for what it's tracking. Reopen only if a concrete complaint names something this loses, not just symmetry for its own sake.
- **A drawer for mobile hub switching.** Hub pills in the header plus the bottom section bar already cover every width. A drawer would be a third copy of the same control.
- **A unified hub+submenu component.** The header and section bars already read as one stacked unit. The only trigger to reopen is mobile's stacked chrome becoming an actual complaint.
- **Forcing all four playback controllers onto one `PlaybackCoordinator` contract.** Costs a real adapter per controller type to save two duplicated lines, with no current bug. Revisit if a fifth playback type forgets the sync.
- **`interneto/tv-multiview`'s channel data.** No stated license, no direct-stream-URL field, ~88 mostly-minor channels. IPTV multi-view shipped as an original grid feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is a namespace, not an identifier anything outside the module sees.
- **Putting Books on `BrowseScaffold`.** Checked 2026-08-30: `BookResult` carries no cover URL at all — libgen's list view does not expose one — so a hero and poster rows would render as blank rectangles. The current text-row list is the right layout for cover-less metadata. Reopen only if a cover source appears.
- **Replacing Manga's grid with `BrowseScaffold`'s rows.** Manga's grid is infinite-scrolling and its card density is a user setting (`MangaSettings.cardDensity`, with a customizer sheet). Fixed-length rows would remove both. Manga could gain a hero *above* its grid, which is a separate and much smaller change.
