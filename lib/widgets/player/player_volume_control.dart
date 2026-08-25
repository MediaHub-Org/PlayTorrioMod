import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'player_glass.dart';

/// Interactive volume slider with boost support (up to 300%).
class PlayerVolumeControl extends StatefulWidget {
  final double volume; // 0.0 to 3.0 (300%)
  final bool isMuted;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;

  const PlayerVolumeControl({
    super.key,
    required this.volume,
    required this.isMuted,
    required this.onVolumeChanged,
    required this.onToggleMute,
  });

  @override
  State<PlayerVolumeControl> createState() => _PlayerVolumeControlState();
}

class _PlayerVolumeControlState extends State<PlayerVolumeControl> {
  bool _isHovered = false;
  static const double _trackWidth = 88.0;

  IconData _getVolumeIcon() {
    if (widget.isMuted || widget.volume == 0) {
      return Icons.volume_off_rounded;
    }
    if (widget.volume > 1.0) {
      return Icons.volume_up_rounded;
    }
    if (widget.volume < 0.5) {
      return Icons.volume_down_rounded;
    }
    return Icons.volume_up_rounded;
  }

  Color _getBoostColor() {
    if (widget.volume <= 1.0) return Colors.white;
    if (widget.volume <= 1.5) return const Color(0xFFF97316); // Orange
    return const Color(0xFFEF4444); // Red
  }

  void _updateFromPosition(double localX) {
    // Normal 0.0 to 1.0 takes up 70% of the bar, Boost 1.0 to 3.0 takes the remaining 30%
    final fraction = (localX / _trackWidth).clamp(0.0, 1.0);
    double newVol;
    if (fraction <= 0.70) {
      newVol = (fraction / 0.70);
    } else {
      newVol = 1.0 + ((fraction - 0.70) / 0.30) * 2.0;
    }
    widget.onVolumeChanged((newVol * 100).round() / 100.0);
  }

  double _getFractionFromVolume(double v) {
    if (widget.isMuted) return 0.0;
    if (v <= 1.0) {
      return (v * 0.70).clamp(0.0, 0.70);
    }
    return (0.70 + ((v - 1.0) / 2.0) * 0.30).clamp(0.70, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveVol = widget.isMuted ? 0.0 : widget.volume;
    final fillFraction = _getFractionFromVolume(effectiveVol);
    final isBoosting = !widget.isMuted && widget.volume > 1.001;
    final boostColor = _getBoostColor();
    final pct = (effectiveVol * 100).round();

    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          final delta = pointerSignal.scrollDelta.dy < 0 ? 0.05 : -0.05;
          final next = (widget.volume + delta).clamp(0.0, 3.0);
          widget.onVolumeChanged((next * 100).round() / 100.0);
        }
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mute / Unmute Button
            PlayerIconButton(
              size: 40,
              iconSize: 22,
              icon: Icon(
                _getVolumeIcon(),
                color: isBoosting ? boostColor : (widget.isMuted ? PlayerTheme.inkSubtle : Colors.white),
              ),
              tooltip: widget.isMuted ? 'Unmute' : 'Mute',
              onPressed: widget.onToggleMute,
            ),

            const SizedBox(width: 4),

            // Volume Slider Track
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (e) => _updateFromPosition(e.localPosition.dx),
              onTapDown: (e) => _updateFromPosition(e.localPosition.dx),
              child: Container(
                width: _trackWidth,
                height: 32,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Background track
                    Container(
                      height: 6,
                      width: _trackWidth,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),

                    // Filled track
                    Container(
                      height: 6,
                      width: _trackWidth * fillFraction,
                      decoration: BoxDecoration(
                        gradient: isBoosting
                            ? const LinearGradient(
                                colors: [Colors.white, Color(0xFFF97316), Color(0xFFEF4444)],
                              )
                            : null,
                        color: isBoosting ? null : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),

                    // Thumb dot
                    Positioned(
                      left: (_trackWidth * fillFraction - 6).clamp(0.0, _trackWidth - 12),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isBoosting ? boostColor : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Percentage Readout
            if (isBoosting || _isHovered) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 36),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    color: isBoosting ? boostColor : PlayerTheme.inkMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
