import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/app_hub.dart';
import '../../widgets/common/nested_navigator.dart';
import '../../widgets/common/universal_play_bar.dart';
import '../../utils/hub_controller.dart';
import '../../utils/hub_navigator.dart';
import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../widgets/common/adaptive_nav_shell.dart';
import '../settings/settings_page.dart';
import 'media_hub.dart';
import 'books_hub.dart';
import 'music_hub.dart';

/// HubPage: the top-level container hosting all primary app hubs
/// (Media, Books, Music) in an IndexedStack, wrapped in the persistent
/// [AdaptiveNavShell] chrome (hub switcher + section row, both nav layers,
/// on every tier). Settings swaps into the same content slot the hubs use
/// rather than routing away, so that chrome stays visible while it's open
/// too -- see [HubController.settingsOpen].
class HubPage extends StatefulWidget {
  const HubPage({super.key});

  @override
  State<HubPage> createState() => _HubPageState();
}

class _HubPageState extends State<HubPage> {
  final FocusNode _focusNode = FocusNode();

  // Each hub is lazily wrapped in its own nested Navigator the first time it's
  // shown, so offstage hubs are not laid out at startup (which can crash pages
  // that assume a non-zero width, and stalls first paint with eager network).
  //
  // Each also gets its own GlobalKey so a pushed detail page can be popped
  // back to root from outside -- see _onHubControllerChanged below.
  final _mediaNavKey = GlobalKey<NavigatorState>();
  final _booksNavKey = GlobalKey<NavigatorState>();
  final _musicNavKey = GlobalKey<NavigatorState>();
  late final List<Widget Function()> _hubBuilders = [
    () => NestedNavigator(navigatorKey: _mediaNavKey, child: const MediaHub()),
    () => NestedNavigator(navigatorKey: _booksNavKey, child: const BooksHub()),
    () => NestedNavigator(navigatorKey: _musicNavKey, child: const MusicHub()),
  ];
  final List<Widget?> _built = List<Widget?>.filled(3, null);

  // Bumped each time Settings closes, so its NestedNavigator gets a fresh
  // key next time it opens -- re-opening Settings always lands back on the
  // settings list, never resumes on whatever sub-page was showing before.
  int _settingsRebuildKey = 0;

  AppHub? _lastHub;
  String? _lastSectionId;

  void _setHub(AppHub hub) {
    HubController.instance.setHub(hub);
  }

  // A pushed detail page (movie/album/book/etc.) lives inside its hub's own
  // NestedNavigator, on top of the section content. Tapping a different hub
  // or section pill already updates HubController fine, but without this the
  // pushed page just keeps covering the screen since nothing pops it -- pills
  // and the bottom bar would look like they'd stopped working. Pop every hub
  // back to its root route whenever the active hub or section actually
  // changes, so the pill/bar tap is always visible.
  void _onHubControllerChanged() {
    final hub = HubController.instance.currentHub;
    final sectionId = HubController.instance.currentSectionId;
    if (hub == _lastHub && sectionId == _lastSectionId) return;
    _lastHub = hub;
    _lastSectionId = sectionId;
    for (final key in [_mediaNavKey, _booksNavKey, _musicNavKey]) {
      key.currentState?.popUntil((route) => route.isFirst);
    }
  }

  void _closeSettings() {
    HubController.instance.closeSettings();
    // Addons may have changed in Settings — drop the cached hubs so each
    // rebuilds and refetches on next show.
    if (mounted) {
      setState(() {
        _built.fillRange(0, _built.length, null);
        _settingsRebuildKey++;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _lastHub = HubController.instance.currentHub;
    _lastSectionId = HubController.instance.currentSectionId;
    HubController.instance.addListener(_onHubControllerChanged);

    // Allow child hub pages to navigate back to the primary media hub.
    HubNavigator.registerGoHome(() => _setHub(AppHub.media));
  }

  @override
  void dispose() {
    HubController.instance.removeListener(_onHubControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  /// TV remote Back/Exit support: Escape pops the current route.
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      // Only pop if there is actually a route to pop. On the root HubPage
      // there is nothing beneath it, so popping would leave a black screen.
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
    }
  }

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
                onSettingsTap: () => HubController.instance.openSettings(),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadii.lg),
                  ),
                  child: ListenableBuilder(
                    listenable: HubController.instance,
                    builder: (context, _) {
                      if (HubController.instance.settingsOpen) {
                        return NestedNavigator(
                          key: ValueKey('settings-$_settingsRebuildKey'),
                          child: SettingsPage(onClose: _closeSettings),
                        );
                      }
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
            // Universal Play Bar. On desktop/tablet it sits 16px above the
            // bottom; on mobile it clears AdaptiveNavShell's bottom tab bar.
            Positioned(
                bottom: tier == ScreenTier.mobile
                    ? AdaptiveNavShell.mobileBottomBarInset(context) + 12
                    : 16,
                left: 12,
                right: 12,
                // UniversalPlayBar hides itself when nothing is playing, so
                // it stays visible across every hub, not just Listen.
                child: const UniversalPlayBar(),
              ),
          ],
        ),
      ),
    );
  }

}
