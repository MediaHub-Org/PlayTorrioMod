import 'package:flutter/services.dart';

class LibassPlugin {
  static const MethodChannel _channel = MethodChannel('libass_plugin');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
