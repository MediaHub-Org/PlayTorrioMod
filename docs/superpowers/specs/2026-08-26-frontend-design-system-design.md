# Frontend design system + adaptive nav — design

Status: approved (checkpoints 1-2), pending final spec review
Author: David7ce + Claude
Date: 2026-08-26

## Problem

PlayTorrio's frontend has no single responsive/visual source of truth:

- Breakpoint checks (`MediaQuery.sizeOf(context).width >= 900`-style) are
  duplicated ad-hoc across 52 files (362 occurrences), each page picking
  its own cutoffs.
- Spacing/radius values are magic numbers repeated per widget, not a
  shared scale.
- Card widgets are near-duplicated per content type (`MovieCard`,
  `IptvChannelCard`, manga/book cover tiles) with no shared shell.
- Navigation chrome (`TopBar` — logo + 3 hub tabs + settings, fixed 60px;
  `SectionTopBar` — 44px horizontal chip row) renders identically on
  every screen size. There is no mobile-native layout: a top-anchored
  3-tab switcher isn't how Netflix/Disney+/Stremio's mobile apps place
  primary navigation (bottom, thumb-reachable).

Goal: a small, reusable design-system layer (breakpoints, spacing,
shared components, adaptive nav) that every hub can draw on, giving the
app one consistent, responsive, "consolidated-app" visual language —
without a mass rewrite and without touching backend/services.

## Non-goals

- Rewriting all 52 files' breakpoint checks in this pass (opportunistic
  migration instead — see Migration).
- Forcing the Listen (Music) hub onto `SectionedHubScaffold`'s structural
  shell — it keeps its own layout shape, just adopts the shared tokens.
- Any change to `lib/services/**` business logic, scrapers, models, or
  APIs. This is a frontend-only pass; backend stays untouched except two
  new additive token files.
- TV gets no separate 10-foot layout tier — it reuses the desktop tier
  (it's a big desktop window today, not a distinct remote-first UI).
- Golden/visual-regression test suite — out of scope for a UI-polish pass.

## Architecture

New files, following the existing `AppThemeService` static-service
pattern (`lib/services/app_theme_service.dart`):

- **`lib/services/app_breakpoints.dart`**
  `enum ScreenTier { mobile, tablet, desktop }` +
  `AppBreakpoints.of(BuildContext)` resolving the tier from
  `MediaQuery.sizeOf(context).width` using the cutoffs already in use
  today (600, 900) — centralizes what's currently duplicated per file.

- **`lib/services/app_spacing.dart`**
  `abstract final class AppSpacing` — an 8pt-grid scale
  (`xs/sm/md/lg/xl`) and `abstract final class AppRadii` for corner
  radii, replacing scattered magic numbers (12, 16, ...).

- Typography is NOT duplicated into a new file — Material3's
  `TextTheme`, already derived from `colorSchemeSeed` in
  `AppThemeService.createThemeData`, covers it.

## Components

Additions under `lib/widgets/common/` (existing convention — that's
where `sectioned_hub_scaffold.dart`, `top_bar.dart`, `section_top_bar.dart`
already live):

- **`premium_card.dart`** — one card shell (poster/backdrop, gradient
  scrim, hover/press physics) that `MovieCard`, `IptvChannelCard`, and
  manga/book cover tiles converge onto over time. Built on
  `AppSpacing`/`AppRadii`.

- **`section_header.dart`** — the "row title + see-all" pattern repeated
  across every slider section, extracted once.

- **`adaptive_nav_shell.dart`** — replaces `HubPage`'s hardcoded `TopBar`
  mount. Reads `AppBreakpoints.of(context)`:
  - `mobile`: bottom tab bar (3 hub tabs, thumb-reachable), `TopBar`
    collapses to logo + settings only.
  - `tablet` / `desktop`: current `TopBar` layout, restyled with the new
    tokens and `premium_card`-style hover treatment on the tabs, no
    structural change.
  - `SectionTopBar` (the per-hub submenu) is unchanged structurally on
    every tier — its horizontal scrollable chip row already behaves like
    Netflix's genre-chip row on mobile. Only reskinned with the new
    tokens.

Both card/header widgets are additive: existing widgets keep working
untouched until a page is deliberately migrated onto the new ones.

## Migration & blast radius

- This pass ships the five new files above, fully additive.
- `lib/pages/hub/hub_page.dart` is the one existing file with a required
  behavior change: it mounts `AdaptiveNavShell` instead of `TopBar`
  directly. That's the entire nav-visible diff for this phase.
- Everything else (the 52 files with ad-hoc `MediaQuery` checks, the
  per-content-type card widgets, section headers across hubs) migrates
  onto the new tokens/widgets opportunistically in later, separate work —
  not in this pass. Keeps the diff reviewable and low-risk.
- `lib/services/**` untouched except the two new additive token files —
  no existing service, model, scraper, or API contract changes. Backend
  and frontend stay decoupled for this work, per direction.

## Testing / verification

- `flutter analyze` clean (0 errors).
- Full `flutter test` suite green (pre-existing live-network flaky tests
  excluded per established pattern).
- One new widget test: `AdaptiveNavShell` tier-branching — mobile tier
  renders the bottom tab bar, tablet/desktop render the top bar. This is
  the one real conditional this phase introduces; everything else is
  presentational.
- Windows release build (`flutter build windows --release`) still
  compiles — this app has a history of native-plugin build fragility
  (`flutter_inappwebview`), worth the one extra verification pass.
- Manual pass: resize the desktop window across the 600/900 breakpoints,
  confirm nav chrome swaps cleanly with no layout jump/overflow.
- No golden/visual-regression tests (out of scope, see Non-goals).

## Follow-up (explicitly not in this pass)

Tracked separately per the user's own sequencing ("first" the interface
decision, everything else after):

1. Sync 3 new upstream commits (`d552781`, `4130aeb`, `4ef5fe0` —
   SubtitleCat integration, app icon overhaul, 250% volume boost, subtitle
   sync/search fixes, Arabic anime section support).
2. Drop Books' `flutter_inappwebview` dependency — it's the only file in
   `lib/` that imports it (`lib/pages/read/book_reader_page.dart`), pulled
   in solely to render EPUB HTML/CSS via `file://` URLs. Manga's reader
   proves in-app reading doesn't need a webview, but manga only renders
   images — EPUB needs actual HTML/CSS rendering, so this isn't a direct
   reuse; it's a separate spike to find a lighter EPUB-to-Flutter-widgets
   renderer (e.g. an HTML-to-RichText package) before committing to
   dropping the dependency.
3. Opportunistic migration of the 52 existing ad-hoc-breakpoint files and
   per-content-type card widgets onto the new tokens/components.
4. General functionality/design improvements — not yet scoped; needs its
   own brainstorming pass once the above is prioritized.
