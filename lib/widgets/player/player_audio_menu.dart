import 'package:flutter/material.dart';
import 'player_glass.dart';

class PlayerAudioTrack {
  final int index;
  final String title;
  final String? language;
  final String? codec;
  final int? channels;
  final bool isDefault;

  const PlayerAudioTrack({
    required this.index,
    required this.title,
    this.language,
    this.codec,
    this.channels,
    this.isDefault = false,
  });
}

/// Audio tracks selector and audio sync offset adjuster.
class PlayerAudioMenu extends StatelessWidget {
  final List<PlayerAudioTrack> audioTracks;
  final int selectedIndex;
  final double delaySec;
  final ValueChanged<int> onTrackSelected;
  final ValueChanged<double> onDelayChanged;
  final VoidCallback onClose;

  const PlayerAudioMenu({
    super.key,
    required this.audioTracks,
    required this.selectedIndex,
    required this.delaySec,
    required this.onTrackSelected,
    required this.onDelayChanged,
    required this.onClose,
  });

  String _getLanguageEmoji(String? lang) {
    if (lang == null) return '🔊';
    final l = lang.toLowerCase();
    if (l.contains('en') || l.contains('eng')) return '🇺🇸';
    if (l.contains('ar') || l.contains('ara')) return '🇸🇦';
    if (l.contains('es') || l.contains('spa')) return '🇪🇸';
    if (l.contains('fr') || l.contains('fre')) return '🇫🇷';
    if (l.contains('de') || l.contains('ger')) return '🇩🇪';
    if (l.contains('it') || l.contains('ita')) return '🇮🇹';
    if (l.contains('ja') || l.contains('jpn')) return '🇯🇵';
    if (l.contains('ko') || l.contains('kor')) return '🇰🇷';
    if (l.contains('ru') || l.contains('rus')) return '🇷🇺';
    return '🌐';
  }

  String? _getTrackSubtitle(PlayerAudioTrack track) {
    final parts = <String>[];
    if (track.language != null && track.language!.isNotEmpty) {
      parts.add(track.language!.toUpperCase());
    }
    if (track.codec != null && track.codec!.isNotEmpty) {
      parts.add(track.codec!.toUpperCase());
    }
    if (track.channels != null && track.channels! > 0) {
      parts.add('${track.channels} ch');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final hasTracks = audioTracks.isNotEmpty;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return PlayerGlassCard(
      width: (360.0).clamp(260.0, screenWidth - 32),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'AUDIO TRACKS',
                      style: TextStyle(
                        color: PlayerTheme.inkSubtle,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (hasTracks)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: PlayerTheme.raised,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${audioTracks.length}',
                        style: const TextStyle(
                          color: PlayerTheme.inkSubtle,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              PlayerIconButton(
                size: 28,
                iconSize: 14,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                onPressed: onClose,
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Track List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: hasTracks
                ? ListView.builder(
                    shrinkWrap: true,
                    itemCount: audioTracks.length,
                    itemBuilder: (context, i) {
                      final track = audioTracks[i];
                      final isSelected = track.index == selectedIndex;
                      final subtitle = _getTrackSubtitle(track);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            onTrackSelected(track.index);
                            onClose();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? PlayerTheme.raised : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? PlayerTheme.edge : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: isSelected ? PlayerTheme.accent : PlayerTheme.raised,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _getLanguageEmoji(track.language),
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        style: TextStyle(
                                          color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (subtitle != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            color: PlayerTheme.inkSubtle,
                                            fontSize: 10.5,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Text(
                      'Default audio stream playing.',
                      style: TextStyle(color: PlayerTheme.inkSubtle, fontSize: 13),
                    ),
                  ),
          ),

          const SizedBox(height: 8),
          const Divider(color: PlayerTheme.edgeSoft, height: 1),
          const SizedBox(height: 8),

          // Audio Sync Offset Row
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Audio Sync Offset',
                      style: TextStyle(
                        color: PlayerTheme.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${delaySec > 0 ? "+" : ""}${delaySec.toStringAsFixed(2)}s',
                          style: TextStyle(
                            color: delaySec != 0 ? PlayerTheme.accent : PlayerTheme.inkSubtle,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (delaySec != 0) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => onDelayChanged(0.0),
                            child: const Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: PlayerTheme.inkSubtle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: PlayerTheme.edgeSoft),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => onDelayChanged(((delaySec - 0.1) * 10).round() / 10.0),
                        child: const Text('−0.1s', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: PlayerTheme.edgeSoft),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => onDelayChanged(((delaySec + 0.1) * 10).round() / 10.0),
                        child: const Text('+0.1s', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
