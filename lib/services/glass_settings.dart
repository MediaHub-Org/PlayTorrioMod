import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global opt-in for the expensive, fully animated liquid-glass experience.
abstract final class GlassSettings {
  static const _preferenceKey = 'full_liquid_glass_enabled';

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    enabled.value = preferences.getBool(_preferenceKey) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    if (enabled.value == value) return;
    enabled.value = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey, value);
  }
}
