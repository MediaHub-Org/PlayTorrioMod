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
