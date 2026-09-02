# TODO — UX/UI pass, 2026-09-02 (session 2)

Raised in one long message. Splitting into groups: active bugs (fix first),
concrete UI tasks (clear enough to just do), and open design questions
(need an answer before touching code — see the bottom).

## Active bugs (investigate/fix first)

- [ ] **Anime fails to load.** Reported just now, no error text/screenshot yet.
  Need: does it spin forever, show an error screen, or crash the app? Nothing
  in this session's diff touches Anime's own code path (AnilistService,
  anime_page.dart) — could be transient (AniList API), or a side effect of
  something shared. Investigating.
- [ ] **Podcasts: clicking a result/card does nothEng open.** Need to check
  `_PodcastCard.onTap` / `PodcastDetailsPage` wiring, and whether this
  regressed when `podcasts_page.dart` was rewritten for the trending-chart
  welcome page and `SimpleSearchPage` integration earlier this session.

## Library: Listen & Read (match/extend Watch's pattern)

- [ ] Listen Library > Saved: add **Radio** as a 4th type filter chip
  alongside Music/Podcasts/Audiobooks (currently 3 — Radio was left out).
- [ ] Decide + apply the best UI for Liked vs. Playlists in Listen's Saved
  (currently: SectionSubTabs pill row switching between a type-filtered
  Liked grid and a separate Playlists list) — confirm this is the shape to
  keep, or should it look more like Watch's own Saved (type chips + status
  chips, no sub-tab at all)? **See question 1 below.**
- [ ] Read Library > Saved: apply the same pattern once settled above.
- [ ] General: "same library as Watch for [Listen/Read], or very similar if
  not improve it and copy for the rest" — once the Listen/Read Saved shape
  is settled, make sure Downloads/In Progress read the same way too where
  it makes sense.

## Music page

- [ ] Play icon on an album cover should flip to a pause icon once that
  album is actually playing (currently probably always shows the play
  glyph regardless of state).
- [ ] Add a hover effect to the album cover's play icon.
- [ ] **Clicking the album cover itself should open the album's own page**,
  not start playback — only the dedicated play icon plays. Match how
  playlist cards already behave (open on tap, play via its own icon).
- [ ] Add a genre filter next to the search icon.
- [ ] Header: next to the search icon (opposite side), add a "Music" title
  label — same treatment `podcasts_page.dart` already got this session.

## Podcasts & Audiobooks

- [ ] Rename the "Podcasts" section/tab label to **"Podcasts & Audiobooks"**
  (it already holds both behind a sub-tab; the label doesn't say so).
- [ ] Remove the extra/duplicate search icon — **which page, which icon
  exactly? See question 2 below**, the request cut off mid-sentence.
- [ ] Remove the top search bar from Audiobooks specifically (within the
  Podcasts & Audiobooks sub-tab) — `SimpleSearchPage` entry point stays,
  just not a second inline one.

## Radio

- [ ] Remove an icon at the top, add a search icon in its place — confirm
  which icon is being removed (needs a look at `radio` page's current
  header first).

## Listen > Library / Read > Books

- [ ] Remove the search bar from Listen > Library (it shouldn't have its
  own — search is a global per-section action elsewhere).

## Manga

- [ ] Add a "Manga" title label, same treatment as Music/Podcasts.
- [ ] Layout order requested: title, then genre-filter pills in the **same
  row** as the customize and search icons, then **Continue Reading first**
  below that. **See question 3 below** — current wording was hard to
  parse exactly, want to confirm the intended order before touching it.

## Settings icon (mobile)

- [ ] On mobile view the Settings icon's position shifts left compared to
  desktop — should stay in the same relative position across breakpoints.
  Fix mobile-first (define the mobile position as the base case, adapt up
  to desktop, not the other way around).

## Process / meta

- [ ] **#12 (Windows close crash)** — candidate fix already shipped this
  session (see `ROADMAP.md`), asked again to "fix for real." Needs the
  hands-on close-while-playing-video verification that's still missing —
  can't do that without UI automation in this environment; flagging back
  to the user rather than re-guessing at more code changes with no new
  evidence.
- [ ] **`ROADMAP.md` "code consistency"** — vague as given; will read
  through and clean up redundant/stale wording once the active bugs above
  are settled, unless a more specific ask is meant.
- [ ] **Stable release build + publish on GitHub for both apps** — moving
  off `(dev)` channel. This is a real, public, hard-to-reverse action
  (version bump, tag, GitHub Actions release run) — **not started, needs
  an explicit go-ahead separately from this list**, not bundled silently
  into a UI pass.

## Open questions (answered inline in chat, tracked here for reference)

1. Listen/Read Saved: keep the current Liked+Playlists sub-tab shape, or
   flatten fully to Watch's type-chip-only pattern (no sub-tab at all)?
2. "Repeated search icon, remove the one on ___" — which page and which of
   the two icons?
3. Manga's exact intended element order (title / pills / customize+search
   row / Continue Reading placement).
