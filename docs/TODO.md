# TODO — UX/UI pass, 2026-09-02 (session 2)

## Done this pass

- [x] **Anime fails to load** — not our bug. AniList's own API is down
  ("temporarily disabled due to severe stability issues", confirmed via a
  direct query). The app already shows a graceful error view instead of
  crashing, just with a misleading "check your internet connection" message.
  Nothing to fix until AniList is back; reword the message if it keeps
  coming up.
- [x] **Podcasts & Audiobooks: duplicate search icon** — real root cause
  found and fixed: `music_page.dart`'s top-right search icon rendered
  unconditionally on every Listen sub-tab, always opening *Music's* own
  inline Search tab regardless of which sub-tab was active — wrong
  destination on Radio/Podcasts, and a visible second icon stacked on
  Podcasts & Audiobooks' own correct one. Now Music-only.
- [x] **"Podcast" renamed "Podcasts & Audiobooks"** everywhere the section
  label shows (bottom bar, chip row, tests).
- [x] **Radio: icon on top removed, real search added** — was showing the
  same wrong shared Music-search icon (see above); now has its own,
  `RadioBrowserService.search` (new, name search via the same free API
  already used for genre browsing).
- [x] **Radio stations can now be liked** — no such capability existed at
  all before. New `RadioLibraryService` (mirrors `PodcastLibraryService`),
  a heart on each station card (no details page to put it on, unlike
  Podcasts/Audiobooks), and Radio joins the Liked type filter chips.
- [x] **Listen Library > Saved: Radio added as a 4th type filter chip**
  (Music/Podcasts/Audiobooks/Radio).
- [x] **Read Library > Saved consistency** — audited against Watch's and
  Listen's chip styling: all three `_likedTypeChip`/`_buildChoiceChip`
  implementations are already pixel-identical. Nothing to change.
- [x] **Remove search from Listen > Library** — already satisfied by the
  shared-icon fix above (Library never had its own, only ever showed the
  wrong shared one).
- [x] **Remove top search from Audiobooks** — same fix; the "duplicate" was
  this same shared icon, not a second one inside Audiobooks itself.
- [x] **Music: play/pause on album & playlist covers** — covers had no play
  affordance at all before (tap always opened the detail page, which was
  already correct, not a regression). Added a hover-fade-in play/pause
  button, self-contained (`_MusicCoverCard`, via
  `MusicPlayerController.instance`/`MusicService.instance` directly).
  Albums show a real playing/paused state (`MusicTrack.albumId` match);
  playlists show a plain play icon (no reverse link from a track back to
  which curated playlist it came from, so no fake state).
- [x] **Music: genre filter next to search** — a `FilterDropdown` reusing
  the existing `_selectGenre`/`_backToGenres` flow the genre-tile slider
  already drove.
- [x] **Music: "Music" title next to search icon** — same treatment
  Podcasts already had.
- [x] **Manga: title + pills/customize/search row + Continue Reading order**
  — confirmed order applied: static "Manga" title, then genre pills +
  customize + search in one row, then Continue Reading, then the grid.
- [x] **Settings icon mobile-position shift** — real cause: desktop
  (`TopBar`) and mobile (`_MobileTopBar`) each hand-tuned their own
  `IconButton` (different size/padding), putting the icon a few pixels off
  between the two. Extracted one shared `SettingsIconButton`
  (`top_bar.dart`), defined mobile-first (the tighter constraint fits both
  cases).

## Still open

- [ ] **Podcasts click-to-open** — checked the code path
  (`_PodcastCard.onTap` → `PodcastDetailsPage`), looks correct and matches
  what worked before. Couldn't reproduce without live interaction — no UI
  automation available in this environment. If this is still happening,
  need the exact screen it's happening on (trending grid vs. search
  results vs. Audiobooks' own cards) to dig further.
- [ ] **#12 (Windows close crash)** — candidate fix already shipped
  (`docs/ROADMAP.md`). Still needs the hands-on close-while-playing-video
  verification that can't be done without UI automation here. No new code
  changes made this pass since there's no new evidence.
- [ ] **`ROADMAP.md` code-consistency cleanup** — light pass done (closed
  items, fixed the nav table, corrected the upstream-tracking claim, in an
  earlier commit this session). Ask was vague; flag a more specific target
  if there's a particular section in mind.
- [ ] **Stable release + GitHub publish for both apps** — explicitly held
  back per your answer ("finish the UX pass first"). Not started.

## Design decisions made along the way

- Listen/Read Saved: kept the Liked (type-filtered)/Playlists sub-tab shape
  rather than flattening to Watch's exact pattern — per your answer
  ("keep the best but must have consistency"), confirmed the chip styling
  itself is identical across all three; the sub-tab exists only because
  Playlists (named collections) has no Watch equivalent to be consistent
  *with*.
