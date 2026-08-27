# Project Roadmap — PlayTorrioV3

This document lists the **outstanding** work for PlayTorrioV3. Completed work is
consolidated into `CHANGELOG.md`.

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
on init and runs a real shutdown sequence in a new `onWindowClose` handler
(`PlaybackCoordinator.stopActive()`, `LocalStreamProxy.instance.stop()`,
`TorrentStreamService().stop()`, then `windowManager.destroy()`) instead of letting
the OS kill the process while the proxy's HTTP server is still bound. Verified via
`flutter analyze`/`flutter test`/a Windows release build, but actually clicking the
close button and confirming no dialog appears needs a human — no agent in this loop
can interact with a live window.

**Closed, unreproducible — mobile section chips overlap the page search icon at
narrow widths.** Originally confirmed via testing 2026-08-26; retested 2026-08-27
by actually running the Windows build at a resized 390px phone-width window
(screenshots via `PrintWindow`, live-driven, not just code review) across Movies,
Audiobooks, and Anime — one page per composition shape (`PageSearchButton` inline,
plain title row, custom `Positioned(top:16,right:16)` row matching `manga_page.dart`).
In every case `SectionTopBar` and the page's own icon row sit in separate rows via
`SectionedHubScaffold`'s `Column[SectionTopBar(), Expanded(section)]` — no Z-overlap
is structurally possible there. What *is* real: the chip strip itself clips at 390px
(trailing chip cut off, reachable only by scrolling) — expected horizontal-scroll
behavior, not a collision. Reopen with the exact device/width/font-scale if seen
again; current build shows no overlap.

## Upcoming (priority order)

Reordered 2026-08-27: testing-confirmed, concrete items first; speculative
architecture and data-blocked items pushed toward the end. Seven items shipped
across this day's passes (Windows-close crash, Music back-button, play-bar like
button, download-from-source-card button, dead-code cleanup, mixed page-transitions,
Books browse view) — see CHANGELOG.

| # | Task                                                                        | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|---|-----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | **QA pass on all 5 platforms** (mobile, tablet, desktop, TV)                | Verify no regressions; TV in particular needs a dedicated D-pad/remote-input pass — reported as needing improvement generally. Still blocking real confidence in everything else on this list, since most of this session's work has only been verified on Windows desktop.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| 2 | **Cast & direction with images**                                            | Narrowed 2026-08-27, anime piece shipped (see CHANGELOG): Movies/Series already had cast+director photos; anime had a "Characters & Cast" row but no director/staff, added via AniList's `staff` field (same API already used for characters, no new data source). What remains is genuinely blocked: manga is scraped from weebcentral.com (plain HTML, text author only, no photo) — a photo would need fuzzy-matching manga titles against AniList's staff data, real risk of attaching the wrong person's photo, held rather than shipped speculatively. Audiobooks' `Audiobook` model has no author/narrator field at all — audiobookbay's scrape doesn't expose the name, let alone a photo. **Blocked** on source data for both.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| 4 | **Migrate the remaining 52 ad-hoc breakpoint checks onto `AppBreakpoints`** | Narrowed 2026-08-27 — the other two parts of this item are done (see CHANGELOG): `TopBar`/`SectionTopBar` now use `AppSpacing`/`AppRadii` wherever the values actually matched (16px padding, 12px radius; values that didn't cleanly match a token, like 22px/6px, were left as literals rather than force-fit), and `TopBar` now reads hub labels/icons from `AppHub.navLabel`/`.navIcon` instead of its own separate hardcoded list. What's left: 52 files still doing ad-hoc `MediaQuery.sizeOf(context).width >= 900`-style checks instead of `AppBreakpoints.of(context)`. Genuinely low-value to batch into one pass (52 independent call sites, no shared risk) — better done opportunistically as each file is next touched for another reason, per the original nav-chrome spec's own migration strategy.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| 5 | **Unified hub + submenu navigation component**                              | Reconsidered 2026-08-27: originally framed as "the global `TopBar` and per-hub `SectionTopBar` are two disconnected bars, consolidate into one component." On reflection this is architecture-for-its-own-sake unless paired with a concrete problem — the two bars already sit stacked directly under each other and read as one unit visually; no testing session has actually flagged this as confusing, unlike the transition-consistency and back-button items that came from direct user reports and are now shipped. Kept on the list as a real idea worth another look once #4 lands (the token work might reveal a natural merge point), but deliberately ranked below every item with actual evidence behind it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| 6 | **Filters for Audiobooks**                                                  | Narrowed 2026-08-27, Music shipped, Radio dropped: Movies/Series got a decade filter + sort dropdown, and Anime got a genre filter (see CHANGELOG) — both reusing the shared `FilterDropdown` widget. Music genre browsing shipped 2026-08-27 too (see CHANGELOG) — turned out not to be a data gap at all: `DeezerApiClient.getGenres()`/`.getGenreArtists()` already existed, unused, wired to Deezer's real public genre API. Radio was removed from this item earlier — it's 8 hardcoded mood tiles, not a filterable catalog, so a filter doesn't apply there regardless of data. What's left: Audiobooks has no genre/category concept at all and no clean path to one (see recommendation below). **Blocked** on data for Audiobooks only. |
| 7 | **Audit cross-section UX consistency (Movies/Series/Anime)**                | Reframed 2026-08-27 per the navigation principle above: rejects the original "merge into one catalog" premise (Stremio-style single grid) in favor of keeping Movies/Series/Anime as separate subcategories and auditing whether the cross-cutting UX is actually consistent across them, since that consistency is what should be unified, not the content. Already consistent: all three now have decade+genre `FilterDropdown`s (see CHANGELOG), all route through `SearchScope`, all play through `PlaybackCoordinator`. One concrete gap found while reframing this item: Anime uses its own `AnimeLibraryService` for favorites/watchlist, separate from the `MyListService` that Movies/Series' Library section reads from — worth checking whether that's a deliberate split (anime tracking needs, e.g., episode progress, that `MyListService` doesn't model) or a real inconsistency worth unifying. Needs its own investigation pass, not a quick patch. |
| 8 | **Read hub: Comics data source**                                            | Looked at porting `ayman708-UX/PlayTorrioV2`'s comics feature (`comics_service.dart`, `readcomicsonline_scraper.dart`, `comic_page_extractor.dart`, browse/details/reader screens — same Dart/Flutter stack, would've been directly adaptable) but **both sources it depends on are dead**: `rcostation.xyz` doesn't resolve (DNS gone), and the fallback `readcomicsonline.ru` returns HTTP 403 on every endpoint even with the exact matching User-Agent (looks like Cloudflare/bot-protection blocking plain HTTP requests, which would block the app's `http` client identically) — verified directly via `curl` on 2026-08-24 and re-verified 2026-08-25, no change. Porting as-is would ship a Comics section that just errors out. Holding until a working source is found — either a fixed/alternate scrape target, or a Stremio-style addon (comics addons exist in that ecosystem, matching how Movies/Series/Manga already work here) instead of raw HTML scraping a single site that can vanish. `ComicsPage` (`lib/pages/catalog/comics_page.dart`) stays a placeholder until then. V2 has no other comics source and no podcast feature at all, so neither could be cross-checked against a second port target. **Blocked** on a source. Note the same "does this site have a real browse endpoint, not just search" check that unblocked Books (2026-08-27, see CHANGELOG) is worth re-trying here if a replacement fiction/comics source is ever found. |
| 9 | **Cloud sync for the JSON backup**                                          | Local export/import shipped (see CHANGELOG) as a flat, versioned JSON envelope specifically so this is a transport change, not a rewrite — wire it up to a cloud backend (own server, or a drop-in like a user's own cloud storage) instead of only writing to a local file. Lowest urgency on this list: local backup already works, this is a convenience upgrade, not a gap.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |

### Recommendations (brainstormed 2026-08-27, not yet approved/scoped)

Thinking-only pass over the undesigned items above — no code changed, nothing
here is committed to. Recommendations, not decisions.

- **#5 Unified nav** — still no concrete problem per the note above. One real
  trigger to watch for: mobile spends 88px of vertical chrome on two stacked
  44px bars (hub tabs + section chips). A collapsed version — tap "Watch" opens
  a dropdown of Movies/Series/Anime instead of an always-visible chip row —
  would reclaim that space on phones specifically. Worth building only if that
  trigger becomes a real complaint, not speculatively.
- **#6 Filters** — Music shipped 2026-08-27 (see CHANGELOG): the recommendation
  here was to try MusicBrainz/Last.fm for genre tags, but a spike found
  something better first — `DeezerApiClient.getGenres()`/`.getGenreArtists()`
  and the `MusicGenre` model already existed in the codebase, wired to Deezer's
  real public `/genre` and `/genre/{id}/artists` endpoints, completely unused.
  No new source needed. Wired into `music_page.dart`'s Genres tab, replacing
  its hardcoded mood-tile fake-search with real genre -> artist browsing.
  Radio — checked: there's no Radio Browser API integration to begin with.
  `music_page.dart`'s Radio tab (`_buildRadioView`) is 8 hardcoded mood tiles
  (Pop Radio, Rap & Hip-Hop, ...) whose `onTap` just fills the search box and
  runs a normal Qobuz search (`_onGenreTap`) — there's no live station catalog
  and no per-item genre data to expose, so a `FilterDropdown` doesn't map onto
  this feature the way it does for Movies/Anime. The ROADMAP #6 framing of
  Radio needing "genre/category data sourced" was wrong — it's not a data gap,
  it's a different shape of feature (curated tiles, not a filterable catalog).
  Drop Radio from #6 rather than trying to unblock it.
  Audiobooks — no clean path found; would need title-matching against Open
  Library/Google Books subject tags, same fuzzy-match risk already flagged for
  manga cast in #2.
- **#8 Comics** — beyond the two dead scrape sources already ruled out, a
  Stremio-style comics addon is the cleaner path (matches how Movies/Series/
  Manga already work here). Worth naming honestly: legal comics-reading sources
  are scarce industry-wide, so this may stay blocked longer than a typical
  "find a better scraper" problem — not purely a technical gap.
- **#9 Cloud sync** — three shapes: full OAuth to Google Drive/OneDrive (heavy,
  per-platform work); a generic WebDAV/S3 endpoint the user points at their own
  server (light, no vendor lock-in, fits the "own server" framing already in
  the note above — leaning here); or GitHub Gist via a personal access token
  (zero setup, fits this app's self-hosted-tool audience as a bonus option
  alongside WebDAV, not a replacement for it).

> **Mobile hub switching via drawer** was dropped: the leftover bottom nav bar it referred to is already gone, and the global `TopBar` (3 fixed hub tabs) + `SectionTopBar` (horizontally-scrolling section chips) already cover every screen width, including mobile — a drawer would duplicate that, not fix a gap.
>
> **IPTV multi-view** shipped (see CHANGELOG) as an original grid feature, not a port of `interneto/tv-multiview` (a pure JS/PWA project, not pullable as a Flutter dependency). Scoped to channels with an already-cached stream, not fresh scans — see the CHANGELOG entry for why.
>
> **`interneto/tv-multiview`'s channel data** (`json-tv/tv-channels.json` -- 96 channels with direct m3u8 URLs, name/logo/category/country) was evaluated as a source for more IPTV channels. Declined: mostly minor national/public broadcasters (34 news, 23 general), the data has no stated license (from `Alplox/json-tv`, marked "(No license)" in their own NOTICE.md), and `HardcodedChannel` has no direct-stream-URL field -- these channels already have a working URL, so bolting them into the existing name+keyword portal-scan model would mean scanning portals for niche broadcasters unlikely to be in that catalog. Using it properly needs a second, direct-play path bypassing the scan entirely -- a real new subsystem, not proportionate to what ~88 working channels (mostly minor) add.

## Architecture: consistency, SOLID, modularity

Cross-cutting cleanup requested — applied consistently rather than as one-off patches.

- **Duplicated widgets with independently-drifting behavior**: `IptvSliderSection`/`MovieSliderSection` scroll-arrow logic, `IptvChannelCard`/`MovieCard` hover-press animation, `IptvHeroCarousel`/the anime hero carousel's PageController+Timer auto-rotate logic, and `MediaHub`/`BooksHub`'s scaffold shell are all done (see CHANGELOG). `MusicHub`/`music_page.dart` stays a deliberately separate third shape (ambient background, keyboard listener, queue/lyrics drawer overlays) rather than being forced into the same abstraction.
- **Playback progress/state syncing to `PlaybackCoordinator`**: evaluated formalizing this into the `activate()` contract. Music and audiobook drive it from their own custom controllers' internal state; video and IPTV share a duplicated 2-line fragment (`setProgress`+`setPlaying` off a `VideoPlayerController`'s `value`) inside otherwise-unrelated listeners. Forcing all four into one contract would mean an adapter per controller type to paper over genuinely different underlying APIs — real design cost to save two lines, with no current bug from the gap. Left as-is; revisit if a fifth playback type actually forgets the sync.
- **Dead code found 2026-08-27**: resolved same day (see CHANGELOG) — `DownloadItem` deleted, `AppRadii` now has a real consumer, `_MobileTopBar` reuses `SidebarLogo`.

> Completed items are in the CHANGELOG — pull latest `upstream/main` and confirm the
> working tree is clean before any commit.
