import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/app_theme_service.dart';
import '../../services/home_page_settings.dart';

/// GPU-accelerated animated ambient background with moving soft-faded
/// light orbs, aurora waves, and gradient meshes themed dynamically.
class AnimatedAmbientBackground extends StatefulWidget {
  final Widget? child;

  const AnimatedAmbientBackground({
    super.key,
    this.child,
  });

  @override
  State<AnimatedAmbientBackground> createState() => _AnimatedAmbientBackgroundState();
}

class _AnimatedAmbientBackgroundState extends State<AnimatedAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    HomePageSettings.changeNotifier.addListener(_onSettingsChanged);
    AppThemeService.currentPalette.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    HomePageSettings.changeNotifier.removeListener(_onSettingsChanged);
    AppThemeService.currentPalette.removeListener(_onSettingsChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, palette, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: HomePageSettings.enableAmbientLights,
          builder: (context, enabled, _) {
            if (!enabled) {
              return Container(
                color: palette.scaffoldBackgroundColor,
                child: widget.child,
              );
            }

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final speed = HomePageSettings.ambientLightSpeed.value;
                final intensity = HomePageSettings.ambientLightIntensity.value;
                final pattern = HomePageSettings.ambientLightPattern.value;
                final t = (_controller.value * speed) % 1.0;

                return CustomPaint(
                  painter: _AmbientBackgroundPainter(
                    t: t,
                    palette: palette,
                    pattern: pattern,
                    intensity: intensity,
                  ),
                  child: widget.child,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AmbientBackgroundPainter extends CustomPainter {
  final double t;
  final AppThemePalette palette;
  final AmbientLightPattern pattern;
  final double intensity;

  _AmbientBackgroundPainter({
    required this.t,
    required this.palette,
    required this.pattern,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Draw base deep background tint
    final bgPaint = Paint()..color = palette.scaffoldBackgroundColor;
    canvas.drawRect(rect, bgPaint);

    final angle = t * 2 * math.pi;
    final primary = palette.primaryColor;
    final accent = palette.accentColor;

    switch (pattern) {
      case AmbientLightPattern.dualOrbs:
        _drawDualOrbs(canvas, size, angle, primary, accent);
        break;
      case AmbientLightPattern.topAurora:
        _drawTopAurora(canvas, size, angle, primary, accent);
        break;
      case AmbientLightPattern.fullMesh:
        _drawFullMesh(canvas, size, angle, primary, accent);
        break;
      case AmbientLightPattern.centerPulse:
        _drawCenterPulse(canvas, size, angle, primary, accent);
        break;
    }
  }

  void _drawDualOrbs(Canvas canvas, Size size, double angle, Color primary, Color accent) {
    // Orb 1 (Top-Left drifting diagonally)
    final cx1 = size.width * (0.22 + 0.12 * math.sin(angle));
    final cy1 = size.height * (0.18 + 0.10 * math.cos(angle * 0.8));
    final r1 = math.max(size.width, size.height) * 0.48;

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: intensity * 0.95),
          primary.withValues(alpha: intensity * 0.40),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx1, cy1), radius: r1));

    canvas.drawCircle(Offset(cx1, cy1), r1, paint1);

    // Orb 2 (Bottom-Right floating opposite)
    final cx2 = size.width * (0.80 - 0.14 * math.cos(angle * 0.9));
    final cy2 = size.height * (0.70 + 0.12 * math.sin(angle * 0.7));
    final r2 = math.max(size.width, size.height) * 0.52;

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: intensity * 0.85),
          accent.withValues(alpha: intensity * 0.30),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx2, cy2), radius: r2));

    canvas.drawCircle(Offset(cx2, cy2), r2, paint2);
  }

  void _drawTopAurora(Canvas canvas, Size size, double angle, Color primary, Color accent) {
    final wave1 = math.sin(angle) * 0.15;
    final wave2 = math.cos(angle * 1.3) * 0.12;

    // Crest 1
    final c1 = Offset(size.width * (0.35 + wave1), size.height * (0.10 + wave2));
    final r1 = size.width * 0.65;
    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: intensity * 1.1),
          accent.withValues(alpha: intensity * 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.40, 1.0],
      ).createShader(Rect.fromCircle(center: c1, radius: r1));

    canvas.drawCircle(c1, r1, p1);

    // Crest 2
    final c2 = Offset(size.width * (0.75 - wave2), size.height * (0.15 + wave1));
    final r2 = size.width * 0.55;
    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: intensity * 0.95),
          primary.withValues(alpha: intensity * 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: c2, radius: r2));

    canvas.drawCircle(c2, r2, p2);
  }

  void _drawFullMesh(Canvas canvas, Size size, double angle, Color primary, Color accent) {
    final pA = Offset(
      size.width * (0.15 + 0.10 * math.sin(angle)),
      size.height * (0.25 + 0.08 * math.cos(angle * 1.1)),
    );
    final pB = Offset(
      size.width * (0.85 - 0.10 * math.cos(angle * 0.7)),
      size.height * (0.35 + 0.10 * math.sin(angle * 0.9)),
    );
    final pC = Offset(
      size.width * (0.50 + 0.12 * math.sin(angle * 1.4)),
      size.height * (0.80 - 0.10 * math.cos(angle * 0.6)),
    );

    final rA = math.max(size.width, size.height) * 0.42;
    final rB = math.max(size.width, size.height) * 0.45;
    final rC = math.max(size.width, size.height) * 0.50;

    final paintA = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: intensity * 0.85),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: pA, radius: rA));

    final paintB = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: intensity * 0.80),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: pB, radius: rB));

    final paintC = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: intensity * 0.75),
          accent.withValues(alpha: intensity * 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: pC, radius: rC));

    canvas.drawCircle(pA, rA, paintA);
    canvas.drawCircle(pB, rB, paintB);
    canvas.drawCircle(pC, rC, paintC);
  }

  void _drawCenterPulse(Canvas canvas, Size size, double angle, Color primary, Color accent) {
    final pulse = 0.85 + 0.15 * math.sin(angle * 1.5);
    final center = Offset(size.width * 0.5, size.height * 0.38);
    final radius = math.max(size.width, size.height) * 0.55 * pulse;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: intensity * 1.15 * pulse),
          accent.withValues(alpha: intensity * 0.50 * pulse),
          Colors.transparent,
        ],
        stops: const [0.0, 0.40, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientBackgroundPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.palette != palette ||
        oldDelegate.pattern != pattern ||
        oldDelegate.intensity != intensity;
  }
}
