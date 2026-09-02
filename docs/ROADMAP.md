# Project Roadmap — PlayTorrioMod

What is **outstanding**. Shipped work lives in [`CHANGELOG.md`](CHANGELOG.md);
this file stays about what is left.

Last reconciled against the tree: **2026-09-02** (v1.1.4, one commit
behind upstream — see *Staying level with upstream* below).

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
| 2 | **media_kit/libmpv playback**          | The engine swap (2026-08-28) changed torrent streaming, live IPTV, subtitle rendering, decoder presets and the volume-boost gesture. Needs a hands-on pass across movie / series / anime / IPTV / music / audiobook. The `mediacodec-copy` fix for the Android black screen (2026-08-29) is part of this. `AudiobookPlayerController` (the background/mini-bar controller) joined this engine 2026-09-02 too — was the one holdout still on `video_player`; needs the same hands-on check as the rest. |
| 3 | **Resume across sources**              | `ContinueWatchingService` absorbed `PlaybackHistoryService`. Resume across movie / series / anime / torrent paths is unconfirmed on a device.                                                                                                                                                             |
| 4 | **QA on all five platforms**           | Mobile, tablet, desktop, TV. TV needs its own D-pad/remote-input pass. Most work to date has only been exercised on Windows desktop and in CI.                                                                                                                                                            |

The `(dev)` channel marker no longer gates on this list (cleared 2026-09-02
by product decision) — these items stay open regardless, worth checking on
hardware when possible.

## Code and consistency

| # | Task                                                                                              | Why it is still open                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|---|---------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 7 | **`music_page.dart` is 6,579 lines** (grew from 5,220 on 2026-09-02, absorbing Audiobooks' Liked/In Progress/Downloads sub-tabs, then Radio's search/liking and the album/playlist play-button work, all the same day) | Four other files are over 2,000. Splitting is worthwhile but is a refactor with no user-visible payoff, so it waits behind anything that a user would notice.                                                                                                                                                                                                                                                                                                                                                                        |
| 8 | **Kotlin Gradle Plugin will break future Flutter builds**                                         | Every Android build warns: the app and six plugins (`package_info_plus`, `shared_preferences_android`, `torrserver_flutter`, `url_launcher_android`, `video_player_android`, `wakelock_plus`) apply KGP, and *"future versions of Flutter will fail to build if your app uses plugins that apply KGP"*. The app's own `build.gradle.kts` can migrate to Built-in Kotlin; the plugins cannot be fixed here — each needs a version that supports it, or an upstream issue. Not urgent, but it is a dated fuse rather than a style nit. |

## Content sources

| #  | Task                           | State                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
|----|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 9  | **Read hub: MOBI/FB2 still unsupported** | PDF shipped 2026-09-02 (see `CHANGELOG.md`) — renders standalone via `pdfrx`, no shared parsing with the EPUB reader, so it was safely addable. MOBI/FB2 are a different shape of work: upstream normalizes both into the same chapter/HTML data the EPUB reader consumes, through a parser service (`dart_mobi`, `fb2_parse`) this fork never ported — real, riskier feature work touching the shared reader, not a drop-in like PDF was. Found during the v1.0.8 merge (2026-08-31). |
| 10 | **Comics data source**         | `ComicsPage` is an honest empty state, not a placeholder pretending to load. Two leads checked 2026-08-29: `newcomic.info` routes every `.cbr` through `florenfile.com` behind Cloudflare's JS challenge — dead for a server-side fetch. `readcomicsonline.lol` looks structurally right (own CDN, direct `.webp` per page, no archive extraction, same shape as Manga) but its chapter/page data loads client-side and the underlying endpoint did not surface from its JS bundles. Confirming it needs live devtools inspection by a human, not blind guessing. |

## Known bugs

| #  | Bug                                                       | Notes                                                                                                                                                                                                                                                                          |
|----|-----------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 12 | **"Unknown hard error" on Windows after closing the app** | Reported 2026-08-31. Candidate fix applied 2026-09-02: `WindowService`'s shutdown path only paused an active video/IPTV player (`PlayerScreen`/`IptvPlayerPage` never registered a full-dispose hook, unlike Music/Audiobooks) — a native window close never runs `State.dispose()`, so their media_kit `Player`'s native decoder threads/GPU surface stayed alive into process teardown. Timing matches: a *different* close-crash fix (`cf97c81`, Aug 28, verified with zero active playback) landed 20 minutes before the media_kit engine swap merged same day; this bug was reported 3 days later, matching the ticket's own "only after specific actions like an active stream" guess. See `CHANGELOG.md` for the fix. **Not yet empirically verified** — this environment has no way to drive the app's UI to start real playback and then close over it; confirmed only that a real `WM_CLOSE` (not a force-kill) with no active player exits clean with zero new Event Viewer entries. Needs a hands-on close-while-playing-video check before this can close for real. |

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

The fork tracks `ayman708-UX/PlayTorrioV3`. As of 2026-09-02 it is **one
commit behind** (`upstream/main` @ `1ea6c5d` — "Bump version to 1.1.0 and
enhance TV calendar, addon management, seeder filters, and semantic continue
watching matcher"; our tree is level with the prior `ad81c7b`). Not merged
yet — noted while checking upstream's own hero image logic for the item 13
work above, not otherwise investigated.

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
