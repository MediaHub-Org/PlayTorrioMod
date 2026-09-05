# Project Roadmap — PlayTorrioMod

What is **outstanding**. Shipped work lives in [`CHANGELOG.md`](CHANGELOG.md).

Last reconciled: **2026-09-03** (v1.1.5, level with upstream `ayman708-UX/PlayTorrioV3` @ `9d34d4c`, merged to `main` at `f5c8b97`). The next 3-commit gap (`ad0e40d`, `6c4d0cf`, `f1f1310`) is merged on branch `upstream-v3-sync-2`, pending review before it lands on `main` — see below.

## Sibling app: PlayTorrioMov

`MediaHub-Org/PlayTorrioMov` is a Media-only fork (Movies & Series, Anime,
Live TV, Library — no Music, no Books). This repo is the primary dev
target; Media-domain changes get ported to Mov manually.

## Navigation principle

Three hubs, four sections each (Library always last):

| Hub    | Sections                                              |
|:-------|:-------------------------------------------------------|
| Watch  | Movies & Series · Anime · Live TV · Library             |
| Listen | Music · Podcasts/Audiobooks (sub-tab) · Radio · Library |
| Read   | Books · Comics · Manga · Library                        |

Check any proposal to merge/flatten sections, or give one hub a different
section count, against this first.

## Blocked on a device

Implemented, analyzer/tests green, unverified on real hardware.

| # | Area | Needs checking |
|---|------|-----------------|
| 1 | Media session | Android shade + iOS lock screen: art/controls/backgrounding/tap-to-return. |
| 2 | media_kit/libmpv playback | Hands-on pass across movie/series/anime/IPTV/music/audiobook. First pass (Windows, movie only, 2026-09-02) found+fixed 2 bugs (mini-bar over video, stuck-loading resume) and reconfirmed #12. Rest unchecked. |
| 3 | Resume across sources | Movie-path bug fixed 2026-09-02 (see #2). Series/anime/torrent unconfirmed. |
| 4 | QA on all 5 platforms | Only Windows desktop + CI exercised so far; mobile/tablet/TV untouched. |

## Code and consistency

| # | Task | Status |
|---|------|--------|
| 7 | `music_page.dart` at 6,579 lines | Refactor with no user-visible payoff; waits behind anything a user would notice. |
| 8 | Kotlin Gradle Plugin (KGP) deprecation | App's own gradle config already matches Flutter's current template — nothing to migrate there. 3 of 6 flagged plugins fixed themselves via `pub upgrade` 2026-09-02. Remaining: `package_info_plus` (needs a major bump), `wakelock_plus` (capped by a transitive constraint), `torrserver_flutter` (no fixed version yet) — none fixable from this repo alone. |

## Content sources

| # | Task | State |
|---|------|-------|
| 9 | Read hub: MOBI/FB2 unsupported | Real feature work (shared parser service upstream never ported), not a drop-in like PDF was. |
| 10 | Comics data source | `ComicsPage` is an honest empty state. Two candidate sources checked and ruled out (Cloudflare-gated / client-side-only data); needs live devtools inspection to find a real one. |

## Known bugs

| # | Bug | Status |
|---|-----|--------|
| 12 | "Unknown hard error" on Windows close | Reproduced live 2026-09-02 with active playback. The `onShutdownDispose` candidate fix does run (confirmed `VideoOutput::~VideoOutput` executes) but the crash still happens after, at the native/OS layer — not the cause originally diagnosed. No playback = clean close every time. No Event Viewer crash entry (Event 1000/WER) to get a faulting module from; needs a local crash dump (`LocalDumps`, admin) or a native debugger at close. Root cause unknown. |

## Requested UI work

Not started: Continue Reading matching Continue Watching's card style
(blocked on Books having no cover art at all); Manga/Comics genre chips
moving to the shared `PillTabRow` instead of their own hand-built ones.

## Staying level with upstream

Tracks `ayman708-UX/PlayTorrioV3`, level as of `9d34d4c`. Merging is never
just `git merge` + green analyzer — past syncs had real breakage git's
3-way diff didn't flag. Routine:

1. `git merge upstream/main --no-commit`, resolve.
2. Identity files always resolve to ours (`pubspec.yaml` version,
   `build.gradle.kts`, `Runner.rc`, `setup.iss`, `build.yml`, etc).
3. Confirm `docs/FORK_DIFFERENCES.md` § *Deliberate divergences* survived.
4. Grep for landmark fixes: `mediacodec-copy`, `MediaSessionService.init`,
   `LibrarySection.values`, namespaced `my_list_item` keys,
   `_buildFatalErrorView`.
5. `flutter analyze` + suite.

2026-09-03: merged the 3-commit gap from `68140b8` on branch
`upstream-v3-sync`, fast-forwarded into `main` at `f5c8b97`.
- `cc07994` (AniList 403 fix) merged: User-Agent/Origin/Referer/15s timeout
  in `anilist_service.dart` landed clean. Its `anime_page.dart` "no data"
  message was moot -- this fork's `_selectGenre` already had its own (and
  correctly scoped) no-data handling; upstream's version of that function
  was still the old one that over-fetched all 8 home sections on every
  genre pick.
- `b0aecf5` (new sources, mapple fix) merged: ~30 scraper sites under
  `lib/services/scraper/sites/`, 7 anime extractors, `video_settings_page.dart`
  additions (libass / Android surface-producer toggles), `stream_model.dart`
  memoization. Kept this fork's `getEffectiveHwdecString()` decoder choice
  in `getVideoControllerConfiguration` over upstream's hardcoded
  `auto-safe` (the "advanced player settings stay" divergence above still
  applies). Took upstream's removal of the `StreamHealthChecker`
  dead-stream probe from `ScraperManager` -- a GET-and-sniff per source was
  adding real latency now that there are ~50 scraper sites; the class
  itself is untouched, just unused from that path. Reopen if dead links
  become a visible complaint.
- `9d34d4c` (upstream's own README) skipped -- this fork keeps its own.

2026-09-05: merged the next 3-commit gap (`ad0e40d`, `6c4d0cf`, `f1f1310`)
on branch `upstream-v3-sync-2` via a real `git merge upstream/main`, not yet
fast-forwarded into `main` -- pending review. `flutter analyze` clean,
full test suite green (305 tests, including the 5 new files this gap
brings: `catalog_extra_test.dart`, `collection_addon_test.dart`,
`cinejoy_scraper_test.dart`, `audio_language_detector_test.dart`,
`test_player_error_filter.dart`).
- `ad0e40d` (audio dub & language filtering, responsive UI) merged: the
  ~1080-line `watch_screen.dart` rewrite came through a real 3-way merge
  with only two textual conflicts -- a duplicate `dart:io`/`dart:ui` import
  line, and the `_SourceCard` tap handler where upstream added
  collection-aware `effectiveTitle` resolution. Combined upstream's
  `effectiveTitle` with this fork's own `pushFullscreen(CinematicSlideRoute(...))`
  navigation (needed for ROADMAP #2's consistent transitions) and kept the
  `onNextEpisode` auto-next-episode wiring and the per-source download
  button, both untouched by upstream and confirmed present after the merge.
  Scraper touch-ups to fsharetv/fsonic/movy/nova/purstream/vidvault/vidzee/
  vixsrc/vuflix/xdownloader applied clean.
- `6c4d0cf` (stream error filtering & health verification) merged: took
  upstream's re-add of `StreamHealthChecker.isAlive` into
  `ScraperManager.scrapeAll` back -- the 2026-09-03 entry above dropped it
  because a GET-and-sniff per source was adding latency across ~50 sources,
  but upstream itself reversed that removal here specifically to catch
  dead/403/429 streams, shipping a `cinejoy_scraper_test.dart` update
  alongside it. That's upstream deliberately deciding it needs the check,
  not drift, so it's back in; reopen if the latency complaint resurfaces.
  `PlayerSettings.isNonFatalError` refinement, the Dulo/VidRock scraper
  fixes, and new CDN referer rules (Dulo, VidFast) applied clean.
  `audiobook_player_screen.dart` and `music_player_controller.dart`
  touch-ups applied clean too -- this fork keeps Music/Audiobooks, unlike
  its own downstream fork PlayTorrioMov, which dropped both.
- `f1f1310` (Stremio catalog-extra handling & collection addons) merged:
  the `AddonCatalogExtra` model, `Movie.isCollection` /
  `MovieDetail.isCollection`, collection-aware Details/Player/WatchScreen UI
  (franchise part numbers, "Play First Movie", IMDb-id normalization for
  scraping/subtitles across collection parts), and
  `AddonManager.getAvailableDiscoverCatalogs` all merged in clean or with
  straightforward conflicts (mostly upstream's additive code layered onto
  this fork's existing getters). `discover_page.dart` turned out to be the
  *same* file on both sides -- this fork already had a small query/genre
  results grid there, pushed from `details_page.dart`. Upstream repurposed
  it into a much bigger Stremio catalog-browser but kept the old `query` /
  `isGenre` constructor params as a "legacy mode" fallback, so this fork's 3
  existing call sites keep working unchanged, no adaptation needed. Its new
  full-browsing mode (`initialCatalog`/`initialAddon`) is present and
  functional but has **no nav entry point**: upstream wired it into
  `dock_settings.dart` / `app_liquid_dock.dart` / `home_page.dart`, all
  three of which this fork deleted in `fa00ca1` when navigation was
  restructured into the Watch/Listen/Read `AppHub` system -- confirmed via
  `git log --diff-filter=D` before resolving, not assumed. Those three
  files stayed deleted (`git rm`'d again during the merge) and the "Liquid
  Dock Navbar" `Positioned` block referencing them was stripped out of
  `discover_page.dart` along with its two now-dead imports. Reopen by
  wiring a Discover entry into `MediaHub`'s section switcher
  (`lib/pages/hub/media_hub.dart`) if/when the feature is wanted -- the
  underlying browsing code doesn't need rewriting to do it, just calling
  from somewhere.

## Declined, so they do not get re-litigated

- Batch-converting all `MediaQuery.sizeOf(context).width` call sites to
  `AppBreakpoints.of(context)` — many are legit geometry math, not nav
  decisions. Migrate opportunistically per-file instead.
- Folding `AnimeLibraryService` into `MyListService` — anime's 4-state
  picker (Watching/Plan/Completed/Dropped) has no honest mapping onto
  `MyListItem`'s 3 flags without lying about state or forking the shared
  model. Reopen only for a concrete complaint, not symmetry.
- A drawer for mobile hub switching — header pills + bottom bar already
  cover it.
- A unified hub+submenu component — already reads as one stacked unit.
- Forcing all playback controllers onto one `PlaybackCoordinator`
  contract — real cost, no current bug.
- `interneto/tv-multiview` channel data — no license, no direct-stream
  field, thin catalog. IPTV multi-view shipped as its own grid instead.
- Renaming the Kotlin source package from `com.example.playtorrio` — an
  internal namespace, not a user-visible identifier.
- Putting Books on `BrowseScaffold` — no cover art source exists to fill
  a hero/poster row. Reopen if one appears.
- Replacing Manga's grid with `BrowseScaffold` rows — would remove
  infinite scroll and the card-density setting.
