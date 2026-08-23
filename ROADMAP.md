# Project Roadmap — PlayTorrioV3

This document lists the **outstanding** work for PlayTorrioV3. Completed work is
consolidated into `CHANGELOG.md`.

## Known issues (found in QA — 2026-08-24 desktop build)

| # | Bug | Details |
|---|-----|---------|
| 1 | **Movies and Series show identical content in Watch** | Root cause identified: `TypeCatalogPage` (`lib/pages/catalog/type_catalog_page.dart`) only fetches in `initState()` and has no `didUpdateWidget`. Switching the Watch section chip from Movies to Series reuses the same `State` (same widget type, no key) instead of remounting, so `widget.type` changes but the already-loaded movie list never refreshes. This is a different bug from the addon item-type mixup fixed earlier (CHANGELOG "Movies and Series now show different, correctly-typed content") — that fix is still correct, this is a separate section-switch bug on top of it. Fix: give `TypeCatalogPage` a `key: ValueKey(type)` in `media_hub.dart`, or add `didUpdateWidget` to re-run `_load()` when `type` changes. |
| 2 | **Bottom play bar's Stop button doesn't actually stop playback** | Root cause identified: every playback source's `onStop` callback passed to `PlaybackCoordinator.activate()` (music/video/audiobook/IPTV) only pauses its controller — it doesn't dispose it, release network/torrent resources, or reset position. `PlaybackCoordinator.stopActive()` calls that same callback, so the Stop button is functionally a second Pause button: the bar hides, but the underlying player, its stream, and any torrent/network connection stay alive in memory. Needs a real per-kind `onStop` that fully tears down playback, not just pauses it. |
| 3 | **Hub tab underline (Watch/Listen/Read) not centered — but reportedly looks right in Read** | `TopBar._hubTab` (`lib/widgets/common/top_bar.dart`) is the single shared implementation for all three hub tabs — same `Column`/underline code regardless of hub, so a real per-hub difference isn't evident from the source. Needs a screenshot/visual repro to pin down whether this is a rendering artifact (e.g. font-metrics-dependent label width) or something else entirely being mistaken for the hub tab underline. |
| 4 | **Opening a movie/series/book detail page hides TopBar elements (search, genres, etc.)** | Reported as uncertain-if-intentional. Detail pages are pushed via plain `Navigator.push(context, ...)`, which should land on the hub's nested navigator *below* the TopBar (same as `WatchScreen`), so the TopBar ought to stay visible and this needs closer investigation — possibly a full-bleed hero image visually overlapping the bar rather than the bar actually being hidden. Needs a design decision either way once confirmed: should the TopBar stay visible on detail pages, or is hiding it intentional for an immersive detail view? |
| 5 | **Movie/series cast list has no photos or character names for most titles** | `CastMember`/`MovieDetail.castMembers` (`lib/models/movie/cast_member.dart`) already supports name + character + photo + TMDB id when the source JSON provides them as objects — but most Stremio addons' `cast` field is just a flat list of name strings (no photo/character data in the protocol), so this degrades gracefully to names-only. Not an app bug so much as a data-source gap; fixing it means enriching cast data from TMDB directly using `MovieDetail.tmdbId` when the addon only supplies names. |

## Upcoming (priority order)

| # | Task | Notes |
|---|------|-------|
| 1 | **QA pass on all 5 platforms** (mobile, tablet, desktop, TV) | Verify no regressions; TV in particular needs a dedicated D-pad/remote-input pass — reported as needing improvement generally |
| 2 | **Mobile hub switching via drawer** | Replace the leftover per-hub bottom nav bar with a drawer |
| 3 | **Read hub: Comics & Books data source** | Comics/Books browsable and readable in the Read hub |
| 4 | **TMDB cast enrichment** | Fetch full cast (photos, character names) from TMDB when the addon only provides plain name strings — see Known issue #5 above |

> See open PRs / issues for the current plan on each item. Completed items are in
> the CHANGELOG — pull latest `upstream/main` and confirm the working tree is clean
> before any commit.
