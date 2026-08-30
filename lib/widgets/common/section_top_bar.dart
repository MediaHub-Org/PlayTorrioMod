import 'package:flutter/material.dart';

import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../utils/hub_controller.dart';

const Color _kBarBackground = Color(0xFF0C0E17);
const Color _kAccent = Color(0xFF7C5CFF);

/// The section switcher shown at the top of each hub's content area, driven by
/// [HubController.currentSections] so it stays in sync with the active hub.
///
/// Tablet and desktop get the full chip bar — every section is visible at a
/// glance and one tap away. Mobile collapses to a dropdown: on a phone the
/// chip row can't fit five sections, so the ones that matter end up scrolled
/// off-screen with nothing indicating they exist. The dropdown always names
/// the current section and reveals the rest in one tap.
class SectionTopBar extends StatelessWidget {
  const SectionTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.of(context) == ScreenTier.mobile;

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: _kBarBackground,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: ListenableBuilder(
        listenable: HubController.instance,
        builder: (context, _) {
          final sections = HubController.instance.currentSections;
          final activeId = HubController.instance.currentSectionId;
          if (sections.isEmpty) return const SizedBox.shrink();

          if (isMobile) {
            return _SectionDropdown(sections: sections, activeId: activeId);
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            itemCount: sections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final section = sections[index];
              return _Chip(
                label: section.label,
                icon: section.icon,
                selected: section.id == activeId,
                onTap: () =>
                    HubController.instance.setCurrentSection(section.id),
              );
            },
          );
        },
      ),
    );
  }
}

/// Mobile-only section selector: a pill naming the active section that opens
/// a menu of the rest.
class _SectionDropdown extends StatelessWidget {
  final List<HubSection> sections;
  final String activeId;

  const _SectionDropdown({required this.sections, required this.activeId});

  @override
  Widget build(BuildContext context) {
    // An id with no matching section (e.g. a hub defaulting to a section it
    // doesn't list) would throw on `firstWhere`; fall back to the first.
    final active = sections.firstWhere(
      (s) => s.id == activeId,
      orElse: () => sections.first,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        child: PopupMenuButton<String>(
          key: const Key('sectionTopBarMobileDropdown'),
          tooltip: 'Change section',
          initialValue: active.id,
          offset: const Offset(0, 40),
          color: const Color(0xFF161A27),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            side: const BorderSide(color: Colors.white12),
          ),
          onSelected: HubController.instance.setCurrentSection,
          itemBuilder: (context) => [
            for (final section in sections)
              PopupMenuItem<String>(
                value: section.id,
                height: 44,
                child: Row(
                  children: [
                    Icon(
                      section.icon,
                      size: 18,
                      color: section.id == active.id
                          ? _kAccent
                          : Colors.white54,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      section.label,
                      style: TextStyle(
                        color: section.id == active.id
                            ? Colors.white
                            : Colors.white70,
                        fontSize: 13.5,
                        fontWeight: section.id == active.id
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: [
                BoxShadow(
                  color: _kAccent.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(active.icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  active.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : Colors.white38,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
