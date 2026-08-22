import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../services/glass_settings.dart';

/// Reusable, const styles keep the package render object from receiving a new
/// style identity and repainting when an unrelated parent rebuilds.
abstract final class PerformanceGlassStyles {
  static const dock = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: 32,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 1.6,
      lightIntensity: 1.45,
      lightColor: Color(0xE6FFFFFF),
      lightDirection: 115,
      borderType: OpticalBorder(
        borderSaturation: 1.55,
        ambientIntensity: 1.2,
        borderSolidity: 0.18,
        lightSpread: 0.72,
      ),
    ),
    appearance: LiquidGlassAppearance(
      color: Color(0x24FFFFFF),
      saturation: 1.12,
      blur: LiquidGlassBlur(sigmaX: 2.5, sigmaY: 2.5),
      shadow: LiquidGlassShadow(
        blur: 14,
        opacity: 0.35,
        color: Color(0xFF000000),
      ),
    ),
    refraction: LiquidGlassRefraction(
      magnification: 1.035,
      chromaticAberration: 0.0022,
      refractionType: OpticalRefraction(
        refraction: 1.52,
        refractionWidth: 28,
        depth: 0.72,
      ),
    ),
  );

  static const sheet = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: 24,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 1.5,
      lightIntensity: 1.35,
      lightColor: Color(0xD9FFFFFF),
      lightDirection: 110,
      borderType: OpticalBorder(
        borderSaturation: 1.4,
        ambientIntensity: 1.15,
        borderSolidity: 0.12,
        lightSpread: 0.68,
      ),
    ),
    appearance: LiquidGlassAppearance(
      color: Color(0x780B0D12),
      saturation: 1.08,
      blur: LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
      shadow: LiquidGlassShadow(
        blur: 18,
        opacity: 0.45,
        color: Color(0xFF000000),
      ),
    ),
    refraction: LiquidGlassRefraction(
      magnification: 1.025,
      chromaticAberration: 0.0018,
      refractionType: OpticalRefraction(
        refraction: 1.5,
        refractionWidth: 26,
        depth: 0.62,
      ),
    ),
  );

  static const menuButton = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: 18,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 1.4,
      lightIntensity: 1.4,
      lightColor: Color(0xE6FFFFFF),
      lightDirection: 110,
      borderType: OpticalBorder(
        borderSaturation: 1.5,
        ambientIntensity: 1.15,
        borderSolidity: 0.15,
        lightSpread: 0.7,
      ),
    ),
    appearance: LiquidGlassAppearance(
      color: Color(0x3813151C),
      saturation: 1.1,
      blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
      shadow: LiquidGlassShadow(
        blur: 8,
        opacity: 0.3,
        color: Color(0xFF000000),
      ),
    ),
    refraction: LiquidGlassRefraction(
      magnification: 1.03,
      chromaticAberration: 0.002,
      refractionType: OpticalRefraction(
        refraction: 1.52,
        refractionWidth: 20,
        depth: 0.7,
      ),
    ),
  );

  static const menu = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: 16,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 1.5,
      lightIntensity: 1.35,
      lightColor: Color(0xD9FFFFFF),
      lightDirection: 110,
      borderType: OpticalBorder(
        borderSaturation: 1.45,
        ambientIntensity: 1.15,
        borderSolidity: 0.12,
        lightSpread: 0.68,
      ),
    ),
    appearance: LiquidGlassAppearance(
      color: Color(0x8813151C),
      saturation: 1.08,
      blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
      shadow: LiquidGlassShadow(
        blur: 12,
        opacity: 0.4,
        color: Color(0xFF000000),
      ),
    ),
    refraction: LiquidGlassRefraction(
      magnification: 1.025,
      chromaticAberration: 0.0018,
      refractionType: OpticalRefraction(
        refraction: 1.5,
        refractionWidth: 24,
        depth: 0.64,
      ),
    ),
  );
}

/// A deliberately constrained use of the package's real lens.
///
/// The expensive setup used previously captured an entire screen and created a
/// lens for every button. This widget uses the package's layout-driven lens
/// directly: one retained shader layer per visible surface, no capture view,
/// no blur pass, no ticker, and no jelly-driven resizing.
class PerformanceLiquidLens extends StatelessWidget {
  final LiquidGlassStyle style;
  final Widget child;
  final bool visible;

  const PerformanceLiquidLens({
    super.key,
    required this.style,
    required this.child,
    this.visible = true,
  });

  BoxDecoration get _fallbackDecoration {
    if (identical(style, PerformanceGlassStyles.dock)) {
      return const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(32)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF01A1D27), Color(0xF012151E)],
        ),
      );
    }
    if (identical(style, PerformanceGlassStyles.sheet)) {
      return const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFA181B23), Color(0xFC0B0D12)],
        ),
      );
    }
    if (identical(style, PerformanceGlassStyles.menuButton)) {
      return const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF01A1D26), Color(0xE613151C)],
        ),
      );
    }
    return const BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFA1A1D26), Color(0xFA13151C)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: GlassSettings.enabled,
      child: child,
      builder: (context, enabled, cachedChild) {
        return RepaintBoundary(
          child: enabled
              ? LiquidGlassLens(
                  style: style,
                  visibility: visible,
                  useImpellerBackdrop: true,
                  child: cachedChild,
                )
              : Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: _fallbackDecoration,
                  child: cachedChild,
                ),
        );
      },
    );
  }
}
