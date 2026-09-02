# Project Roadmap — PlayTorrioMod

What is **outstanding**. Shipped work lives in [`CHANGELOG.md`](CHANGELOG.md);
this file stays about what is left.

Last reconciled against the tree: **2026-09-02** (v1.1.4, level with
upstream @ `ad81c7b`).

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

The `(dev)` channel marker no longer gates on this list (cleared 2026-09-02
by product decision) — these items stay open regardless, worth checking on
hardware when possible.

## Code and consistency

| # | Task                                                                                              | Why it is still open                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|---|---------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 7 | **`music_page.dart` is 5,220 lines**                                                              | Four other files are over 2,000. Splitting is worthwhile but is a refactor with no user-visible payoff, so it waits behind anything that a user would notice.                                                                                                                                                                                                                                                                                                                                                                        |
| 8 | **Kotlin Gradle Plugin will break future Flutter builds**                                         | Every Android build warns: the app and six plugins (`package_info_plus`, `shared_preferences_android`, `torrserver_flutter`, `url_launcher_android`, `video_player_android`, `wakelock_plus`) apply KGP, and *"future versions of Flutter will fail to build if your app uses plugins that apply KGP"*. The app's own `build.gradle.kts` can migrate to Built-in Kotlin; the plugins cannot be fixed here — each needs a version that supports it, or an upstream issue. Not urgent, but it is a dated fuse rather than a style nit. |

## Content sources

| #  | Task                           | State                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
|----|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 9  | **Read hub: MOBI/FB2 still unsupported** | PDF shipped 2026-09-02 (see `CHANGELOG.md`) — renders standalone via `pdfrx`, no shared parsing with the EPUB reader, so it was safely addable. MOBI/FB2 are a different shape of work: upstream normalizes both into the same chapter/HTML data the EPUB reader consumes, through a parser service (`dart_mobi`, `fb2_parse`) this fork never ported — real, riskier feature work touching the shared reader, not a drop-in like PDF was. Found during the v1.0.8 merge (2026-08-31). |
| 10 | **Comics data source**         | `ComicsPage` is an honest empty state, not a placeholder pretending to load. Two leads checked 2026-08-29: `newcomic.info` routes every `.cbr` through `florenfile.com` behind Cloudflare's JS challenge — dead for a server-side fetch. `readcomicsonline.lol` looks structurally right (own CDN, direct `.webp` per page, no archive extraction, same shape as Manga) but its chapter/page data loads client-side and the underlying endpoint did not surface from its JS bundles. Confirming it needs live devtools inspection by a human, not blind guessing. |
| 11 | **Cast photos for Audiobooks** | Movies/Series, Anime and Manga all have them. Audiobooks stays blocked: AniList does not catalog narrators, and AudiobookBay's listing HTML has no narrator field beyond free text. Would need a narrator-photo database that does not appear to exist publicly.                                                                                                                                                                                                                                                                                                  |

## Known bugs

| #  | Bug                                                       | Notes                                                                                                                                                                                                                                                                          |
|----|-----------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 12 | **"Unknown hard error" on Windows after closing the app** | Reported 2026-08-31. Not yet reproduced/triaged — need a stack trace or exact repro steps (does it happen on every close, or only after specific actions like an active torrent/stream? does it show a dialog or just appear in Event Viewer?) before this can be root-caused. |

## Requested UI work

| #  | Task                                                                                         | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|----|----------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 13 | **Hero carousel image quality/cropping — Live TV still open** | Requested 2026-09-01. Anime shipped 2026-09-02; Movies & Series shipped 2026-09-02 in a second pass, once it turned out its hero still rendered via plain `Image.network` (no caching, dead-center alignment) despite Anime already having moved to `CachedNetworkImage` + an upward alignment bias — see `CHANGELOG.md`. **Live TV** (`iptv_hero_carousel.dart:234-238`) already uses a proper `channel.backdropUrl` with `BoxFit.cover` — the code shape looks right, so the reported cropping/low-res is more likely either the source images themselves being low-res, or the crop region disagreeing with `BoxFit.cover`'s centring for these specific images; needs an actual look at the rendered carousel on a device, not a code-only fix. |
| 14 | **Books, Podcast, Music on the same UX/UI as Anime** | Requested 2026-09-01, investigated same day, sharpened 2026-09-02 to specifically call out Podcasts. Radio's actual bug (fake genre search instead of real stations) shipped 2026-09-02 — see `CHANGELOG.md`. What's left is purely cosmetic: Music/Podcasts/Radio all live inside `music_page.dart`'s own bespoke `Stack`-based layout (ambient background, custom tab switching) rather than `BrowseScaffold`'s hero+rows shape Anime uses — a deliberate divergence per `sectioned_hub_scaffold.dart`'s own doc comment ("Music opts out... genuinely different shape"). Moving Music/Podcasts/Radio onto `BrowseScaffold` is a real redesign (new hero data per tab, row layout for a UI that's currently one continuous scroll) — still needs a go-ahead before reworking a page that already opted out on purpose. Books has its own separate blocker (see Declined section below): `BookResult` carries no cover URL at all, so a hero/rows layout would render blank regardless. |

## Staying level with upstream

The fork tracks `ayman708-UX/PlayTorrioV3`. As of 2026-09-02 it is **zero
commits behind** (`upstream/main` @ `ad81c7b`, merged same day — see
`CHANGELOG.md` for what landed).

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
