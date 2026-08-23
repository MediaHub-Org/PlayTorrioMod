import 'package:flutter/material.dart';

import '../../utils/app_hub.dart';
import '../../utils/hub_controller.dart';
import 'sidebar_logo.dart';

/// The slim global top bar shown above every hub.
///
/// Holds the PlayTorrio logo (so the icon stays visible), the
/// Watch / Listen / Read hub switcher, and a Settings button. The per-hub
/// sidebar below it shows only the sections of the current hub, and replaces
/// its own logo/switcher with the name of the currently selected section.
class TopBar extends StatelessWidget {
  /// The height available to the bar. Callers should inset their content by
  /// this amount so nothing sits beneath the bar.
  final double height;

  /// Invoked when the settings (gear) button is tapped.
  final VoidCallback? onSettingsTap;

  const TopBar({super.key, this.height = 60, this.onSettingsTap});

  static const _hubs = [
    (hub: AppHub.media, label: 'Watch', icon: Icons.movie_filter_rounded),
    (hub: AppHub.music, label: 'Listen', icon: Icons.music_note_rounded),
    (hub: AppHub.books, label: 'Read', icon: Icons.auto_stories_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D15),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const SidebarLogo(),
          const Spacer(),
          ListenableBuilder(
            listenable: HubController.instance,
            builder: (context, _) {
              final current = HubController.instance.currentHub;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final h in _hubs) _hubTab(context, h, current),
                ],
              );
            },
          ),
          const SizedBox(width: 20),
          if (onSettingsTap != null)
            _settingsButton(onTap: onSettingsTap!),
        ],
      ),
    );
  }

  Widget _settingsButton({required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Settings',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.04),
        foregroundColor: Colors.white70,
      ),
      icon: const Icon(Icons.settings_rounded, size: 20),
    );
  }

  /// A top-level "you are here" tab: label + icon with an animated underline,
  /// no fill or border — sits visually above the section chip bar beneath it.
  Widget _hubTab(
    BuildContext context,
    ({AppHub hub, String label, IconData icon}) h,
    AppHub current,
  ) {
    final selected = current == h.hub;
    final color = selected ? Colors.white : Colors.white54;
    return Padding(
      padding: const EdgeInsets.only(left: 22),
      child: InkWell(
        onTap: () => HubController.instance.setHub(h.hub),
        borderRadius: BorderRadius.circular(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(h.icon, color: color, size: 17),
                const SizedBox(width: 6),
                Text(
                  h.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 2,
              width: selected ? 22 : 0,
              decoration: const BoxDecoration(
                color: Color(0xFF7C5CFF),
                borderRadius: BorderRadius.all(Radius.circular(1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}