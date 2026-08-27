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

**Implemented, awaiting manual confirmation — "Unknown error" dialog after closing
the Windows app** (see CHANGELOG). `WindowService` now calls `setPreventClose(true)`
on init and runs a real shutdown sequence in `onWindowClose`
(`PlaybackCoordinator.stopActive()`, `LocalStreamProxy.instance.stop()`,
`TorrentStreamService().stop()`, then `windowManager.destroy()`) instead of letting
the OS kill the process while the proxy's HTTP server is still bound. Verified via
`flutter analyze`/`flutter test`/a release build, but clicking the close button and
confirming no dialog appears needs a human — no agent here can interact with a
live window.

**Closed, unreproducible — mobile section chips overlapping the page search icon
at narrow widths.** Retested 2026-08-27 by actually running the Windows build at a
resized 390px phone-width window (screenshots via `PrintWindow`, live-driven) across
Movies, Audiobooks, and Anime — one page per composition shape. `SectionTopBar` and
each page's own icon row sit in separate rows via `SectionedHubScaffold`'s
`Column[SectionTopBar(), Expanded(section)]` — no Z-overlap is structurally
possible there. The chip strip does clip at 390px (trailing chip cut off, reachable
by scrolling) — expected horizontal-scroll behavior, not a collision. Reopen with
the exact device/width/font-scale if seen again.

## Upcoming (priority order)

Testing-confirmed, concrete items first; speculative and data-blocked items
pushed toward the end. A favorites/progress-consistency audit across all three
hubs (2026-08-27) found the same class of bug in Anime and the Read hub, plus
missing favorites in Books and Podcasts — all shipped same day, see CHANGELOG.
Everything below is what's left after that audit.

| # | Task | Notes |
|---|---|---|
| 1 | **QA pass on all 5 platforms** (mobile, tablet, desktop, TV) | Verify no regressions; TV needs a dedicated D-pad/remote-input pass. Most of this work has only been verified on Windows desktop — blocks real confidence in everything else here. |
| 2 | **Merge `ContinueWatchingService`/`PlaybackHistoryService`'s duplicate write** | Investigated 2026-08-27 (see CHANGELOG) — not simple duplication, kept separate for now. Both save on the same 5-second timer in `player_screen.dart`, a real duplicate write, but the two stores differ in three real ways (90%-completion purge, per-show vs. per-episode dedup, and `PlaybackHistoryService.getProgress` being the only resume fallback for entry points other than the Continue Watching row) that a merge would need to preserve correctly. **Blocked** on live-device playback testing across movie/series/anime/torrent resume paths to verify a merge doesn't regress any of the three. |
| 3 | **Cast & direction with images** | Movies/Series and Anime (via AniList's `staff` field) both have cast+director photos now (see CHANGELOG). Manga (weebcentral.com, plain HTML, text-only author) and Audiobooks (`Audiobook` model has no author/narrator field) remain **blocked** on source data — fuzzy-matching manga titles against AniList's staff risks attaching the wrong photo. |
| 4 | **Migrate the remaining 52 ad-hoc breakpoint checks onto `AppBreakpoints`** | `TopBar`/`SectionTopBar`'s token migration is done (see CHANGELOG). 52 files still do ad-hoc `MediaQuery.sizeOf(context).width` checks instead of `AppBreakpoints.of(context)`. Low-value to batch (52 independent call sites, no shared risk) — better done opportunistically as each file is next touched for another reason. |
| 5 | **Unified hub + submenu navigation component** | No concrete problem yet — `TopBar` and `SectionTopBar` already sit stacked and read as one unit; no report has flagged this as confusing. Real trigger to watch for: mobile spends 88px of vertical chrome on two stacked 44px bars — a collapsed per-hub dropdown could reclaim that. Build only if that becomes a real complaint. |
| 6 | **Filters for Audiobooks** | Movies/Series/Anime/Music all have real genre filters now (see CHANGELOG — Music's came from previously-unused Deezer API calls already in the codebase, no new source needed). Audiobooks has no genre/category concept and no clean path to one without the same title-matching risk flagged for manga in #3. **Blocked** on data. |
| 7 | **Read hub: Comics data source** | Both prior scrape targets are dead: `rcostation.xyz` (DNS gone) and `readcomicsonline.ru` (HTTP 403 on every endpoint even with a matching User-Agent — verified via curl 2026-08-24/25). Need a working source — an alternate scrape target, or a Stremio-style comics addon (matches how Movies/Series/Manga already work). `ComicsPage` stays a placeholder until then. **Blocked** on a source; will also need the Books/Podcasts favorites treatment (see CHANGELOG) once unblocked. |

> **Declined/dropped ideas** (kept short so they don't get re-litigated): mobile
> hub switching via a drawer — `TopBar`+`SectionTopBar` already cover every width
> including mobile, a drawer would duplicate that. IPTV multi-view shipped as an
> original grid feature (see CHANGELOG), not a port of `interneto/tv-multiview`
> (pure JS/PWA, not a Flutter dependency). That project's channel data (96
> channels, no stated license, no direct-stream-URL field on `HardcodedChannel`)
> was evaluated and declined — not proportionate to what ~88 mostly-minor
> channels would add.

## Architecture: consistency, SOLID, modularity

- **Playback progress/state syncing to `PlaybackCoordinator`**: Music/audiobook
  drive it from their own custom controllers; video/IPTV share a duplicated
  2-line fragment. Forcing all four into one contract costs a real adapter per
  controller type to save two lines, with no current bug. Left as-is; revisit
  if a fifth playback type actually forgets the sync.

> Completed items are in the CHANGELOG — pull latest `upstream/main` and confirm
> the working tree is clean before any commit.
