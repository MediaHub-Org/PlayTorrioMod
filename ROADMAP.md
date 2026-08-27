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
hubs (2026-08-27) found the same class of bug in Anime and the Read hub, and
Books' missing favorites feature — all three shipped same day, see CHANGELOG.
Podcasts' missing favorites feature (#2) is the one still open from that audit.

| # | Task | Notes |
|---|---|---|
| 1 | **QA pass on all 5 platforms** (mobile, tablet, desktop, TV) | Verify no regressions; TV needs a dedicated D-pad/remote-input pass. Most of this work has only been verified on Windows desktop — blocks real confidence in everything else here. |
| 2 | **Add favorites to Podcasts** | The only Listen-hub subcategory with no favorite/subscribe concept — Music has `MusicLibraryService.likedTracks`, correctly surfaced in its own Library tab. Add a like/subscribe button backed by a small local store mirroring the Manga/Audiobook/Books pattern (see CHANGELOG), surfaced alongside Music's liked tracks and playlists. |
| 3 | **Investigate `ContinueWatchingService`/`PlaybackHistoryService` duplication** | Found while fixing the Read hub's History-tab bug (see CHANGELOG): two separate, unreconciled progress stores exist for Watch-hub content. `ContinueWatchingService` (own storage) powers the Home page's Continue Watching row and already handles Anime. `PlaybackHistoryService` powers `CollectionPage`'s History tab, written only by `player_screen.dart`. Neither reads from or writes to the other. Needs its own investigation before deciding whether to merge or if the split is deliberate. |
| 4 | **Cast & direction with images** | Movies/Series and Anime (via AniList's `staff` field) both have cast+director photos now (see CHANGELOG). Manga (weebcentral.com, plain HTML, text-only author) and Audiobooks (`Audiobook` model has no author/narrator field) remain **blocked** on source data — fuzzy-matching manga titles against AniList's staff risks attaching the wrong photo. |
| 5 | **Migrate the remaining 52 ad-hoc breakpoint checks onto `AppBreakpoints`** | `TopBar`/`SectionTopBar`'s token migration is done (see CHANGELOG). 52 files still do ad-hoc `MediaQuery.sizeOf(context).width` checks instead of `AppBreakpoints.of(context)`. Low-value to batch (52 independent call sites, no shared risk) — better done opportunistically as each file is next touched for another reason. |
| 6 | **Unified hub + submenu navigation component** | No concrete problem yet — `TopBar` and `SectionTopBar` already sit stacked and read as one unit; no report has flagged this as confusing. Real trigger to watch for: mobile spends 88px of vertical chrome on two stacked 44px bars — a collapsed per-hub dropdown could reclaim that. Build only if that becomes a real complaint. |
| 7 | **Filters for Audiobooks** | Movies/Series/Anime/Music all have real genre filters now (see CHANGELOG — Music's came from previously-unused Deezer API calls already in the codebase, no new source needed). Audiobooks has no genre/category concept and no clean path to one without the same title-matching risk flagged for manga in #4. **Blocked** on data. |
| 8 | **Read hub: Comics data source** | Both prior scrape targets are dead: `rcostation.xyz` (DNS gone) and `readcomicsonline.ru` (HTTP 403 on every endpoint even with a matching User-Agent — verified via curl 2026-08-24/25). Need a working source — an alternate scrape target, or a Stremio-style comics addon (matches how Movies/Series/Manga already work). `ComicsPage` stays a placeholder until then. **Blocked** on a source; will also need Books' favorites treatment (see CHANGELOG) once unblocked. |
| 9 | **Cloud sync for the JSON backup** | Local export/import already works as a flat, versioned JSON envelope (see CHANGELOG) — this is a transport change, not a rewrite. Options: full OAuth to Google Drive/OneDrive (heavy, per-platform); a generic WebDAV/S3 endpoint pointed at the user's own server (light, no vendor lock-in — leaning here); GitHub Gist via a personal access token (zero setup, good bonus alongside WebDAV). Whichever is picked needs to cover the new favorite stores from #2 and Books (see CHANGELOG) too. Lowest urgency — local backup already works. |

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
