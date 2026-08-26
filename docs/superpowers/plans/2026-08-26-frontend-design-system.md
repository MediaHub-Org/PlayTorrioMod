# Frontend Nav Chrome (AppBreakpoints + AdaptiveNavShell) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the app a single source of truth for responsive tiers and spacing, and a mobile-native nav shell (bottom tab bar on phone, existing `TopBar` unchanged on tablet/desktop) — without touching backend/services or any file outside the five listed below.

**Architecture:** Two new static-service files (`AppBreakpoints`, `AppSpacing`/`AppRadii`) follow the existing `AppThemeService` pattern. A small additive edit to `AppHub` gives it `navLabel`/`navIcon` getters. A new `AdaptiveNavShell` widget picks tablet/desktop's existing `TopBar` or a new mobile bottom-tab-bar based on `AppBreakpoints.of(context)`. `HubPage` mounts `AdaptiveNavShell` instead of `TopBar` directly — the only existing file with a required behavior change.

**Tech Stack:** Flutter 3.44 (stable), Dart, `flutter_test` (widget/unit tests), package name `playtorrio`.

**Spec:** `docs/superpowers/specs/2026-08-26-frontend-design-system-design.md`

## Global Constraints

- No changes to `lib/services/**` business logic, scrapers, or models — only two new additive files (`app_breakpoints.dart`, `app_spacing.dart`).
- No changes to `lib/widgets/common/top_bar.dart` or `lib/widgets/common/section_top_bar.dart` in this plan — reused as-is.
- No new dependencies in `pubspec.yaml` — everything here is plain Flutter/Dart.
- `lib/pages/hub/hub_page.dart` is the only existing file with a structural/behavioral change (Task 5). `lib/utils/app_hub.dart` (Task 3) also gets a small additive edit — new `navLabel`/`navIcon` getters only, zero change to the enum's existing values, order, or `.index`-based usage elsewhere — per the spec's Components section.
- `flutter analyze` must stay at the same or fewer issues than before this plan starts (0 errors either way).
- `flutter test` full suite must not regress below this branch's actual baseline: 122/128 passing. 6 pre-existing failures (`test/download_service_test.dart`'s serialization round-trip, 5 in `test/models/my_list_item_test.dart` around `uniqueKey`/type-prefix behavior) are reproducible and unrelated to this plan — confirmed pre-existing on the base commit, out of scope to fix here. The previously-documented live-network-flaky set (`movy_scraper_test.dart` etc.) may also still apply on top of these 6; treat any failure outside these known files as a real regression.
- Package imports in tests use `package:playtorrio/...`, matching every existing test file.

---

### Task 1: `AppBreakpoints`

**Files:**
- Create: `lib/services/app_breakpoints.dart`
- Test: `test/services/app_breakpoints_test.dart`

**Interfaces:**
- Consumes: nothing (foundational).
- Produces: `enum ScreenTier { mobile, tablet, desktop }`; `abstract final class AppBreakpoints` with `static const double tablet = 600`, `static const double desktop = 900`, `static ScreenTier tierForWidth(double width)`, `static ScreenTier of(BuildContext context)`. Later tasks call `AppBreakpoints.of(context)` and compare against `ScreenTier.mobile`/`.tablet`/`.desktop`.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/app_breakpoints_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/services/app_breakpoints.dart';

void main() {
  group('AppBreakpoints.tierForWidth', () {
    test('below 600 is mobile', () {
      expect(AppBreakpoints.tierForWidth(599), ScreenTier.mobile);
    });

    test('600 is tablet (lower bound inclusive)', () {
      expect(AppBreakpoints.tierForWidth(600), ScreenTier.tablet);
    });

    test('899 is tablet (upper bound)', () {
      expect(AppBreakpoints.tierForWidth(899), ScreenTier.tablet);
    });

    test('900 is desktop (lower bound inclusive)', () {
      expect(AppBreakpoints.tierForWidth(900), ScreenTier.desktop);
    });

    test('very wide is desktop', () {
      expect(AppBreakpoints.tierForWidth(2560), ScreenTier.desktop);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/app_breakpoints_test.dart`
Expected: FAIL — `Error: Not found: 'package:playtorrio/services/app_breakpoints.dart'` (file doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/services/app_breakpoints.dart
import 'package:flutter/widgets.dart';

/// The three responsive tiers used by nav chrome across the app.
enum ScreenTier { mobile, tablet, desktop }

/// Single source of truth for the width cutoffs used to pick [ScreenTier].
/// Replaces the ad-hoc `MediaQuery.sizeOf(context).width >= 900`-style
/// checks scattered across the app.
abstract final class AppBreakpoints {
  /// Below this width is [ScreenTier.mobile].
  static const double tablet = 600;

  /// At/above this width is [ScreenTier.desktop]. Between [tablet] and
  /// this is [ScreenTier.tablet].
  static const double desktop = 900;

  /// Pure width-to-tier mapping, kept separate from [of] so it's directly
  /// unit-testable without pumping a widget tree.
  static ScreenTier tierForWidth(double width) {
    if (width >= desktop) return ScreenTier.desktop;
    if (width >= tablet) return ScreenTier.tablet;
    return ScreenTier.mobile;
  }

  static ScreenTier of(BuildContext context) =>
      tierForWidth(MediaQuery.sizeOf(context).width);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/app_breakpoints_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/app_breakpoints.dart test/services/app_breakpoints_test.dart
git commit -m "feat: add AppBreakpoints, single source of truth for responsive tiers"
```

---

### Task 2: `AppSpacing` / `AppRadii`

**Files:**
- Create: `lib/services/app_spacing.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `abstract final class AppSpacing` with `static const double xs = 4`, `sm = 8`, `md = 16`, `lg = 24`, `xl = 32`; `abstract final class AppRadii` with `static const double sm = 8`, `md = 12`, `lg = 16`, `xl = 24`. Task 4 uses `AppSpacing.md` and `AppSpacing.xs`.

No dedicated test: this file has no logic, only named constants — nothing for a test to assert beyond "the value equals the value," which the "No Placeholders" rule treats as a fake test. Verified instead by `flutter analyze` and by Task 4's widget test rendering correctly with these values applied.

- [ ] **Step 1: Write the file**

```dart
// lib/services/app_spacing.dart

/// 8pt-grid spacing scale shared across the app's chrome. Replaces magic
/// numbers (12, 16, ...) repeated per widget.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner-radius scale matching the values already in use across the
/// app's cards and panels.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}
```

- [ ] **Step 2: Verify it compiles cleanly**

Run: `flutter analyze lib/services/app_spacing.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/app_spacing.dart
git commit -m "feat: add AppSpacing/AppRadii shared token scale"
```

---

### Task 3: `AppHub` nav metadata

**Files:**
- Modify: `lib/utils/app_hub.dart` (full file, currently 7 lines)

**Interfaces:**
- Consumes: nothing.
- Produces: `AppHub.navLabel` (`String`) and `AppHub.navIcon` (`IconData`) getters. Task 4's mobile tab bar calls both. Enum values/order (`media`, `books`, `music`) and their `.index` (0, 1, 2) are unchanged — `HubPage._hubBuilders[index]` and every other existing `.index`/switch usage keeps working.

No dedicated test: covered end-to-end by Task 4's widget test, which asserts the literal label text ("Watch"/"Listen"/"Read") renders for each hub at the mobile tier — that exercises `navLabel` for real, so a second isolated test would just re-assert the same switch statement via a different path.

- [ ] **Step 1: Replace the file**

```dart
// lib/utils/app_hub.dart
import 'package:flutter/material.dart';

/// The top-level content hubs in the app.
enum AppHub {
  media, // Movies, Series, Anime
  books, // Audiobooks, Books, Manga
  music; // Music, Radio, Podcasts (future)

  /// Label shown in nav chrome (TopBar, and the mobile bottom tab bar).
  String get navLabel => switch (this) {
        AppHub.media => 'Watch',
        AppHub.books => 'Read',
        AppHub.music => 'Listen',
      };

  /// Icon shown in nav chrome.
  IconData get navIcon => switch (this) {
        AppHub.media => Icons.movie_filter_rounded,
        AppHub.books => Icons.auto_stories_rounded,
        AppHub.music => Icons.music_note_rounded,
      };
}
```

- [ ] **Step 2: Verify existing usages still compile**

Run: `flutter analyze lib/utils/app_hub.dart lib/pages/hub/hub_page.dart lib/utils/hub_controller.dart lib/widgets/common/top_bar.dart`
Expected: `No issues found!` — confirms the enum's existing consumers (`hub_page.dart`'s `_hubBuilders[index]`, `hub_controller.dart`'s switches, `top_bar.dart`'s own private hub list) are unaffected by the additive getters.

- [ ] **Step 3: Commit**

```bash
git add lib/utils/app_hub.dart
git commit -m "feat: add AppHub.navLabel/navIcon for shared nav-chrome metadata"
```

---

### Task 4: `AdaptiveNavShell`

**Files:**
- Create: `lib/widgets/common/adaptive_nav_shell.dart`
- Test: `test/widgets/adaptive_nav_shell_test.dart`

**Interfaces:**
- Consumes: `AppBreakpoints.of(BuildContext)` / `ScreenTier` (Task 1), `AppSpacing.md`/`.xs` (Task 2), `AppHub.navLabel`/`.navIcon` (Task 3), existing `TopBar` (`lib/widgets/common/top_bar.dart`, constructor `TopBar({double height = 60, VoidCallback? onSettingsTap})`), existing `HubController.instance` (`currentHub` getter, `setHub(AppHub)` method, is a `ChangeNotifier`).
- Produces: `class AdaptiveNavShell extends StatelessWidget` with constructor `AdaptiveNavShell({required Widget child, VoidCallback? onSettingsTap})` and `static const double mobileBottomBarHeight = 64`. Task 5 (`hub_page.dart`) constructs it and reads `AdaptiveNavShell.mobileBottomBarHeight`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/adaptive_nav_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/utils/app_hub.dart';
import 'package:playtorrio/utils/hub_controller.dart';
import 'package:playtorrio/widgets/common/adaptive_nav_shell.dart';
import 'package:playtorrio/widgets/common/top_bar.dart';

Widget wrap(Widget child) => MaterialApp(home: child);

void setSurfaceWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    HubController.instance.setHub(AppHub.media);
  });

  group('AdaptiveNavShell', () {
    testWidgets('mobile tier shows the bottom tab bar, not TopBar', (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('adaptiveNavMobileBar')), findsOneWidget);
      expect(find.byType(TopBar), findsNothing);
      expect(find.text('Watch'), findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
    });

    testWidgets('tablet tier shows TopBar, not the bottom tab bar', (tester) async {
      setSurfaceWidth(tester, 700);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byType(TopBar), findsOneWidget);
      expect(find.byKey(const Key('adaptiveNavMobileBar')), findsNothing);
    });

    testWidgets('desktop tier shows TopBar, not the bottom tab bar', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byType(TopBar), findsOneWidget);
      expect(find.byKey(const Key('adaptiveNavMobileBar')), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/adaptive_nav_shell_test.dart`
Expected: FAIL — `Error: Not found: 'package:playtorrio/widgets/common/adaptive_nav_shell.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/widgets/common/adaptive_nav_shell.dart
import 'package:flutter/material.dart';

import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../utils/app_hub.dart';
import '../../utils/hub_controller.dart';
import 'top_bar.dart';

/// Tier-aware nav chrome wrapping a hub's content area.
///
/// Desktop/tablet keep the existing [TopBar] unchanged. Mobile collapses
/// the top bar to logo + settings only and moves hub switching to a
/// bottom tab bar, matching where Netflix/Disney+/Stremio place primary
/// navigation on phones (thumb reach) instead of a top-anchored switcher.
class AdaptiveNavShell extends StatelessWidget {
  /// Height of the mobile bottom tab bar. Callers positioning other
  /// bottom-anchored chrome (e.g. a mini player) above it on mobile
  /// should offset by at least this much.
  static const double mobileBottomBarHeight = 64;

  final Widget child;
  final VoidCallback? onSettingsTap;

  const AdaptiveNavShell({
    super.key,
    required this.child,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final tier = AppBreakpoints.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    if (tier == ScreenTier.mobile) {
      return Column(
        children: [
          SizedBox(height: topPadding),
          _MobileTopBar(onSettingsTap: onSettingsTap),
          Expanded(child: child),
          const _MobileHubTabBar(),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(height: topPadding),
        TopBar(onSettingsTap: onSettingsTap),
        Expanded(child: child),
      ],
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  final VoidCallback? onSettingsTap;

  const _MobileTopBar({this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0D15),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Image.asset('assets/icon.png', width: 28, height: 28, fit: BoxFit.contain),
          const Spacer(),
          if (onSettingsTap != null)
            IconButton(
              onPressed: onSettingsTap,
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
            ),
        ],
      ),
    );
  }
}

class _MobileHubTabBar extends StatelessWidget {
  const _MobileHubTabBar();

  static const _tabs = [AppHub.media, AppHub.music, AppHub.books];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('adaptiveNavMobileBar'),
      height: AdaptiveNavShell.mobileBottomBarHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0D15),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: ListenableBuilder(
        listenable: HubController.instance,
        builder: (context, _) {
          final current = HubController.instance.currentHub;
          return Row(
            children: [
              for (final hub in _tabs)
                Expanded(
                  child: _MobileHubTab(hub: hub, selected: hub == current),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MobileHubTab extends StatelessWidget {
  final AppHub hub;
  final bool selected;

  const _MobileHubTab({required this.hub, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white54;
    return InkWell(
      onTap: () => HubController.instance.setHub(hub),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(hub.navIcon, color: color, size: 22),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hub.navLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/adaptive_nav_shell_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/common/adaptive_nav_shell.dart test/widgets/adaptive_nav_shell_test.dart
git commit -m "feat: add AdaptiveNavShell, mobile-aware nav chrome"
```

---

### Task 5: Wire `AdaptiveNavShell` into `HubPage`

**Files:**
- Modify: `lib/pages/hub/hub_page.dart:1-15` (imports), `:92` (`_topBarHeight` field), `:94-181` (`build()`)

**Interfaces:**
- Consumes: `AdaptiveNavShell` and `AdaptiveNavShell.mobileBottomBarHeight` (Task 4), `AppBreakpoints.of`/`ScreenTier` (Task 1).
- Produces: nothing new — this is the integration point, no other task depends on `HubPage`.

- [ ] **Step 1: Update imports**

In `lib/pages/hub/hub_page.dart`, replace this line:

```dart
import '../../widgets/common/top_bar.dart';
```

with:

```dart
import '../../services/app_breakpoints.dart';
import '../../widgets/common/adaptive_nav_shell.dart';
```

(`HubPage` no longer builds `TopBar` directly, so its import is dropped; `AdaptiveNavShell` picks it internally.)

- [ ] **Step 2: Remove the now-unused `_topBarHeight` field**

Delete this line (currently right before `build()`):

```dart
  static const double _topBarHeight = 60;
```

- [ ] **Step 3: Replace `build()`'s top-bar + content Positioned widgets with `AdaptiveNavShell`**

Replace the whole `build()` method with:

```dart
  @override
  Widget build(BuildContext context) {
    final tier = AppBreakpoints.of(context);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF080A0F),
        body: Stack(
          children: [
            // Nav chrome + content: TopBar on tablet/desktop, a collapsed
            // top bar + bottom tab bar on mobile. See AdaptiveNavShell.
            Positioned.fill(
              child: AdaptiveNavShell(
                onSettingsTap: () async {
                  await Navigator.push(
                    context,
                    LiquidRevealRoute(
                      page: const SettingsPage(),
                      tapPosition: null,
                    ),
                  );
                  // Addons may have changed in Settings — drop the cached
                  // hubs so each rebuilds and refetches on next show.
                  if (mounted) {
                    setState(() => _built.fillRange(0, _built.length, null));
                  }
                },
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                  ),
                  child: ListenableBuilder(
                    listenable: HubController.instance,
                    builder: (context, _) {
                      final index = HubController.instance.currentHub.index;
                      // Lazily materialize the active hub on first show.
                      if (_built[index] == null) {
                        _built[index] = _hubBuilders[index]();
                      }
                      return IndexedStack(
                        index: index,
                        children: [
                          _built[0] ?? const SizedBox.shrink(),
                          _built[1] ?? const SizedBox.shrink(),
                          _built[2] ?? const SizedBox.shrink(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            // Universal Play Bar (hidden during intro)
            // On desktop/tablet it sits 16px above the bottom; on mobile
            // it clears AdaptiveNavShell's bottom tab bar.
            if (!_showIntro)
              Positioned(
                bottom: tier == ScreenTier.mobile
                    ? AdaptiveNavShell.mobileBottomBarHeight + 12
                    : 16,
                left: 12,
                right: 12,
                // UniversalPlayBar hides itself when nothing is playing, so
                // it stays visible across every hub, not just Listen.
                child: const UniversalPlayBar(),
              ),
            // Intro Splash Screen
            Positioned.fill(child: _buildIntroOverlay(context)),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: Verify it compiles and existing tests still pass**

Run: `flutter analyze`
Expected: same or fewer issues than the pre-plan baseline, 0 errors.

Run: `flutter test`
Expected: same pass count as the pre-plan baseline, plus the 8 new tests from Tasks 1 and 4 (5 + 3). The 3 known live-network-flaky tests may still fail independent of this change — check by name if anything fails, per this repo's established pattern.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/hub/hub_page.dart
git commit -m "feat: mount AdaptiveNavShell in HubPage for mobile-aware nav"
```

---

### Task 6: Final verification + changelog

**Files:**
- Modify: `CHANGELOG.md` (append a new dated section, following the existing top-of-file convention used for prior entries).

**Interfaces:**
- Consumes: nothing.
- Produces: nothing (terminal task).

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: 0 errors (matches or improves on the pre-plan baseline).

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all tests pass except the pre-existing known-flaky live-network ones (`test/services/movy_scraper_test.dart` and the anime/IPTV-reddit live-extractor tests) — confirm any failure is one of those by name, not a new regression.

- [ ] **Step 3: Windows release build**

Run: `flutter build windows --release`
Expected: `Built build\windows\x64\runner\Release\playtorrio.exe` with no errors (warnings from `flutter_inappwebview`'s own CMake file are pre-existing and unrelated).

- [ ] **Step 4: Manual resize check**

Run the built exe (or `flutter run -d windows`), resize the window across ~500px, ~700px, ~1000px widths. Confirm: below 600px shows the collapsed top bar + bottom tab bar with no overflow; 600-899px and 900px+ both show the original `TopBar`; the `UniversalPlayBar` (if something is playing) never overlaps the bottom tab bar at any width.

- [ ] **Step 5: Add the changelog entry**

Add this section to `CHANGELOG.md`, directly after the existing top header (matching the file's established per-change entry format):

```markdown
### Frontend nav chrome — 2026-08-26
- Added `AppBreakpoints`/`ScreenTier` (mobile/tablet/desktop, 600/900 cutoffs) as the single source of truth for responsive tiers, and `AppSpacing`/`AppRadii` as a shared 8pt-grid token scale — both follow `AppThemeService`'s existing static-service pattern.
- Added `AdaptiveNavShell`: `HubPage` now shows a thumb-reachable bottom tab bar on mobile (matching Netflix/Disney+/Stremio's mobile nav placement) instead of the same top-anchored `TopBar` used on every screen size. Tablet/desktop are unchanged.
- Additive-only pass: no existing service, model, or scraper touched; `TopBar`/`SectionTopBar` reused as-is. Full design and what's intentionally deferred (opportunistic migration of the 52 files with ad-hoc breakpoint checks, restyling `TopBar` onto the new tokens) is in `docs/superpowers/specs/2026-08-26-frontend-design-system-design.md`.
```

- [ ] **Step 6: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: log frontend nav chrome work in changelog"
```
