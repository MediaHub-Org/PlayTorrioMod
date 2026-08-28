# Project Roadmap — PlayTorrioV3

This document lists the **outstanding** work for PlayTorrioV3. Completed work,
shipped features, and resolved cleanup are consolidated into `CHANGELOG.md` —
this file only stays about what's left.

## Navigation principle (2026-08-27)

Three top-level hubs stay the core navigation: **Watch, Read, Listen**. Content
within each hub is organized into subcategories (Movies/Series/Anime under
Watch; Manga/Comics/Books/Audiobooks under Read; Music/Radio/Podcasts under
Listen) — not merged into one undifferentiated catalog or list. Filters and
features are designed around demonstrated user intent, not an exhaustive list
of content types built out speculatively up front. Search, filters, favorites,
and the playback experience stay consistent across every section — that
cross-cutting consistency is what "unified" means here, not the content itself.
Any future item proposing to merge, flatten, or collapse distinct content-type
subcategories should be checked against this principle first.

## Known issues

**Implemented, awaiting manual confirmation — media_kit/libmpv engine swap**
(see CHANGELOG, 2026-08-28 merge). Upstream fully replaced fvp/mdk with
media_kit+libmpv; merge conflicts resolved, `flutter analyze`/`flutter test`
pass, and automated launch/close cycles against the built Windows exe are
clean. What's *not* yet confirmed: actual playback correctness on a live
device — torrent streaming, live IPTV, subtitle rendering (libass toggle),
decoder presets, and the volume-boost gesture all changed under the hood and
need a real hands-on pass across movie/series/anime/IPTV/music/audiobook
before trusting this in production.

**Implemented, awaiting manual confirmation — `ContinueWatchingService`/
`PlaybackHistoryService` merge** (see CHANGELOG). Investigated first (three
real behavioral differences found, not simple duplication), then merged with
the user's go-ahead: `ContinueWatchingService` now carries a second
`historyItems` log (per-episode, never purged) alongside the existing
per-show `activeItems`, and `PlaybackHistoryService` is deleted entirely.
Also fixed a real latent bug found while merging — every
`addPostFrameCallback` write in that file needed an explicit `scheduleFrame()`
it wasn't getting, caught by the new `continue_watching_service_test.dart`.
`flutter analyze`/`flutter test` pass, but resume across movie/series/anime/
torrent paths on a live device hasn't been confirmed yet.

## Upcoming (priority order)

Testing-confirmed, concrete items first; speculative and data-blocked items
pushed toward the end. A favorites/progress-consistency audit across all three
hubs (2026-08-27) found the same class of bug in Anime and the Read hub, plus
missing favorites in Books and Podcasts — all shipped same day, see CHANGELOG.
Everything below is what's left after that audit.

| # | Task | Notes |
|---|---|---|
| 1 | **QA pass on all 5 platforms** (mobile, tablet, desktop, TV) | Verify no regressions; TV needs a dedicated D-pad/remote-input pass. Most of this work has only been verified on Windows desktop — blocks real confidence in everything else here. |
| 2 | **Cast & direction with images — Audiobooks** | Movies/Series, Anime, and now Manga (see CHANGELOG, 2026-08-29) all have cast/staff photos. Audiobooks stays **blocked**: unlike Manga (fuzzy-matched against AniList by title), there's no equivalent photo source for audiobook narrators/authors at all — AniList doesn't catalog audiobook narrators, and AudiobookBay's own listing HTML (checked 2026-08-29, same technique as the genre-filter feature) has no narrator field beyond the free-text title. Would need a dedicated narrator-photo database, which doesn't appear to exist as a free/public API. |
| 3 | **Read hub: Comics data source — build the scraper + reader** | **Unblocked 2026-08-29**: `newcomic.info` (DataLife Engine CMS) is live, unauthenticated, and browsable by category (`/dc`, `/marvel`, etc.) — verified via curl. Each entry page (e.g. `/89613-the-flash-vol-6-35.html`) links to a `.cbr` archive on a third-party file host (florenfile.com in the sample checked) — structurally the same "scrape a listing, resolve a file-host link, download" shape as the existing AudiobookBay scraper, not a direct-read/stream source. Real remaining work before this is a shippable feature, not yet attempted (out of scope for this pass — new dependency + new reader page is architectural-sized, needs a design pass first): (1) resolve florenfile.com's actual download link from its landing page (untested — file hosts often gate this behind a wait-timer or JS challenge); (2) extract page images from the downloaded `.cbr` (RAR) / `.cbz` (ZIP) archive — viable pub.dev packages exist (`unrar`, `koni_rar`) but unverified against a real file; (3) build a page-by-page comic reader UI (no equivalent exists yet, unlike Books' EPUB reader). `ComicsPage` stays a placeholder until this is built. |

> **Declined/dropped ideas** (kept short so they don't get re-litigated): mobile
> hub switching via a drawer — `TopBar`+`SectionTopBar` already cover every width
> including mobile, a drawer would duplicate that. IPTV multi-view shipped as an
> original grid feature (see CHANGELOG), not a port of `interneto/tv-multiview`
> (pure JS/PWA, not a Flutter dependency). That project's channel data (96
> channels, no stated license, no direct-stream-URL field on `HardcodedChannel`)
> was evaluated and declined — not proportionate to what ~88 mostly-minor
> channels would add. Unified hub + submenu navigation component — no concrete
> problem exists (`TopBar`/`SectionTopBar` already read as one stacked unit, no
> report has flagged confusion); only real trigger to reopen is mobile's 88px of
> stacked-bar chrome becoming an actual complaint.

## Architecture: consistency, SOLID, modularity

- **Playback progress/state syncing to `PlaybackCoordinator`**: Music/audiobook
  drive it from their own custom controllers; video/IPTV share a duplicated
  2-line fragment. Forcing all four into one contract costs a real adapter per
  controller type to save two lines, with no current bug. Left as-is; revisit
  if a fifth playback type actually forgets the sync.
- **52 files still do ad-hoc `MediaQuery.sizeOf(context).width` checks** instead
  of `AppBreakpoints.of(context)` (`TopBar`/`SectionTopBar`'s own token
  migration is done, see CHANGELOG). Not worth a dedicated batch pass — 52
  independent call sites, no shared risk, no user-visible bug. Migrate
  opportunistically whenever a file is next touched for another reason.

> Completed items are in the CHANGELOG — pull latest `upstream/main` and confirm
> the working tree is clean before any commit.
