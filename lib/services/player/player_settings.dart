import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart';

/// Available decoder preset types tailored for each platform.
enum DecoderPreset {
  hardwareAuto('Hardware Accelerated (Auto)', 'Fastest performance, GPU hardware decoded with automatic software fallback.'),
  hardwareSafe('Hardware Safe Copy', 'GPU decoded with surface copy to fix frame tearing/glitches on certain chipsets.'),
  softwareSafe('Software Safe (Perfect A/V Sync)', 'CPU decoded via FFmpeg/dav1d. Recommended on slow internet & Android to eliminate buffer desync.'),
  nvidiaCuda('NVIDIA CUDA / NVDEC', 'Dedicated NVIDIA hardware acceleration for Windows & Linux.'),
  custom('Custom Decoder Chain', 'User-defined prioritized decoder fallback list.');

  final String title;
  final String description;
  const DecoderPreset(this.title, this.description);
}

/// Buffer resilience cushion preset for network streams.
enum BufferResiliencePreset {
  minimal('Minimal (1s / 50 pkts)', 'Fast start, for high-speed local streams.', 1000, 50),
  standard('Standard (3s / 150 pkts)', 'Balanced buffering for general streaming.', 3000, 150),
  highResilience('High Resilience (6s / 300 pkts)', 'Recommended for Android & Wi-Fi. Pre-buffers cushion to prevent rebuffer stalls & A/V drift.', 6000, 300),
  maximum('Maximum (12s / 600 pkts)', 'Extra large buffer for torrent streaming & congested connections.', 12000, 600),
  custom('Custom Buffer', 'Custom duration and packet count.', 6000, 300);

  final String label;
  final String subtitle;
  final int durationMs;
  final int packetCount;
  const BufferResiliencePreset(this.label, this.subtitle, this.durationMs, this.packetCount);
}

/// Central service managing video engine properties, decoder fallback chains,
/// buffer resilience, and anti-desync options across all platforms.
abstract final class PlayerSettings {
  static const _keyDecoderPreset = 'player_decoder_preset';
  static const _keyForceSoftwareDecoding = 'player_force_software_decoding';
  static const _keyCustomDecoders = 'player_custom_decoders';
  static const _keyBufferPreset = 'player_buffer_preset';
  static const _keyCustomBufferMs = 'player_custom_buffer_ms';
  static const _keyCustomBufferCount = 'player_custom_buffer_count';
  static const _keyEnableNetworkReconnect = 'player_enable_network_reconnect';
  static const _keyReconnectDelayMax = 'player_reconnect_delay_max';
  static const _keyAutoResyncOnStall = 'player_auto_resync_on_stall';
  static const _keyLowLatency = 'player_low_latency';
  static const _keyHardwareAudioClock = 'player_hardware_audio_clock';
  static const _keyAudioDelayDefault = 'player_audio_delay_default';

  // ValueNotifiers for reactive UI binding
  static final ValueNotifier<DecoderPreset> decoderPreset =
      ValueNotifier<DecoderPreset>(DecoderPreset.hardwareAuto);
  static final ValueNotifier<bool> forceSoftwareDecoding =
      ValueNotifier<bool>(false);
  static final ValueNotifier<List<String>> customDecoders =
      ValueNotifier<List<String>>(<String>[]);
  static final ValueNotifier<BufferResiliencePreset> bufferPreset =
      ValueNotifier<BufferResiliencePreset>(
        // On Android default to high resilience to combat Wi-Fi drops & sync loss
        Platform.isAndroid ? BufferResiliencePreset.highResilience : BufferResiliencePreset.standard,
      );
  static final ValueNotifier<int> customBufferMs = ValueNotifier<int>(6000);
  static final ValueNotifier<int> customBufferCount = ValueNotifier<int>(300);
  static final ValueNotifier<bool> enableNetworkReconnect = ValueNotifier<bool>(true);
  static final ValueNotifier<int> reconnectDelayMax = ValueNotifier<int>(5);
  static final ValueNotifier<bool> autoResyncOnStall = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> lowLatency = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> hardwareAudioClock = ValueNotifier<bool>(true);
  static final ValueNotifier<double> audioDelayDefault = ValueNotifier<double>(0.0);

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  /// Returns available decoder presets for the current OS platform.
  static List<DecoderPreset> getAvailablePresetsForPlatform() {
    if (Platform.isAndroid) {
      return [
        DecoderPreset.hardwareAuto,
        DecoderPreset.hardwareSafe,
        DecoderPreset.softwareSafe,
        DecoderPreset.custom,
      ];
    } else if (Platform.isWindows) {
      return [
        DecoderPreset.hardwareAuto,
        DecoderPreset.hardwareSafe,
        DecoderPreset.nvidiaCuda,
        DecoderPreset.softwareSafe,
        DecoderPreset.custom,
      ];
    } else if (Platform.isMacOS || Platform.isIOS) {
      return [
        DecoderPreset.hardwareAuto,
        DecoderPreset.hardwareSafe,
        DecoderPreset.softwareSafe,
        DecoderPreset.custom,
      ];
    } else {
      // Linux & other
      return [
        DecoderPreset.hardwareAuto,
        DecoderPreset.nvidiaCuda,
        DecoderPreset.softwareSafe,
        DecoderPreset.custom,
      ];
    }
  }

  /// Returns all available raw decoders suitable for custom decoder chain building on current platform.
  static List<String> getAvailableRawDecoders() {
    if (Platform.isAndroid) {
      return ['AMediaCodec:copy=0', 'AMediaCodec', 'AMediaCodec:copy=1', 'dav1d', 'FFmpeg'];
    } else if (Platform.isWindows) {
      return ['MFT:d3d=11:copy=0', 'D3D11:copy=0', 'D3D11:copy=1', 'CUDA:copy=0', 'DXVA', 'dav1d', 'FFmpeg'];
    } else if (Platform.isMacOS || Platform.isIOS) {
      return ['VT:copy=0', 'VT', 'VT:copy=1', 'dav1d', 'FFmpeg'];
    } else {
      return ['VAAPI:copy=0', 'VAAPI', 'CUDA:copy=0', 'dav1d', 'FFmpeg'];
    }
  }

  /// Initializes preferences from disk.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final presetStr = prefs.getString(_keyDecoderPreset);
    if (presetStr != null) {
      decoderPreset.value = DecoderPreset.values.firstWhere(
        (p) => p.name == presetStr,
        orElse: () => DecoderPreset.hardwareAuto,
      );
    } else {
      decoderPreset.value = DecoderPreset.hardwareAuto;
    }

    forceSoftwareDecoding.value = prefs.getBool(_keyForceSoftwareDecoding) ?? false;

    final savedCustom = prefs.getStringList(_keyCustomDecoders);
    if (savedCustom != null && savedCustom.isNotEmpty) {
      customDecoders.value = savedCustom;
    } else {
      customDecoders.value = _getDefaultDecodersForPreset(decoderPreset.value);
    }

    final bufStr = prefs.getString(_keyBufferPreset);
    if (bufStr != null) {
      bufferPreset.value = BufferResiliencePreset.values.firstWhere(
        (b) => b.name == bufStr,
        orElse: () => Platform.isAndroid
            ? BufferResiliencePreset.highResilience
            : BufferResiliencePreset.standard,
      );
    }

    customBufferMs.value = prefs.getInt(_keyCustomBufferMs) ?? 6000;
    customBufferCount.value = prefs.getInt(_keyCustomBufferCount) ?? 300;
    enableNetworkReconnect.value = prefs.getBool(_keyEnableNetworkReconnect) ?? true;
    reconnectDelayMax.value = prefs.getInt(_keyReconnectDelayMax) ?? 5;
    autoResyncOnStall.value = prefs.getBool(_keyAutoResyncOnStall) ?? true;
    lowLatency.value = prefs.getBool(_keyLowLatency) ?? false;
    hardwareAudioClock.value = prefs.getBool(_keyHardwareAudioClock) ?? true;
    audioDelayDefault.value = prefs.getDouble(_keyAudioDelayDefault) ?? 0.0;
  }

  /// Returns the effective decoder list for the current platform and user settings.
  /// CRASH-FREE GUARANTEE: Ensures 'FFmpeg' (Software decoding) is always present at the end
  /// so playback NEVER fails or crashes if hardware decoders fail.
  static List<String> getEffectiveDecoders() {
    if (forceSoftwareDecoding.value) {
      return ['FFmpeg', 'dav1d'];
    }

    List<String> list;
    if (decoderPreset.value == DecoderPreset.custom && customDecoders.value.isNotEmpty) {
      list = List<String>.from(customDecoders.value);
    } else {
      list = _getDefaultDecodersForPreset(decoderPreset.value);
    }

    // Safety fallback check: Ensure FFmpeg is present
    if (!list.contains('FFmpeg')) {
      list.add('FFmpeg');
    }
    return list;
  }

  static List<String> _getDefaultDecodersForPreset(DecoderPreset preset) {
    switch (preset) {
      case DecoderPreset.softwareSafe:
        return ['FFmpeg', 'dav1d'];

      case DecoderPreset.hardwareSafe:
        if (Platform.isAndroid) {
          return ['AMediaCodec:copy=1', 'dav1d', 'FFmpeg'];
        } else if (Platform.isWindows) {
          return ['D3D11:copy=1', 'DXVA', 'dav1d', 'FFmpeg'];
        } else if (Platform.isMacOS || Platform.isIOS) {
          return ['VT:copy=1', 'dav1d', 'FFmpeg'];
        } else {
          return ['VAAPI:copy=1', 'dav1d', 'FFmpeg'];
        }

      case DecoderPreset.nvidiaCuda:
        if (Platform.isWindows) {
          return ['CUDA:copy=0', 'D3D11:copy=0', 'dav1d', 'FFmpeg'];
        } else {
          return ['CUDA:copy=0', 'VAAPI:copy=0', 'dav1d', 'FFmpeg'];
        }

      case DecoderPreset.hardwareAuto:
      case DecoderPreset.custom:
        if (Platform.isWindows) {
          return ['MFT:d3d=11:copy=0', 'D3D11:copy=0', 'CUDA:copy=0', 'DXVA', 'dav1d', 'FFmpeg'];
        } else if (Platform.isMacOS || Platform.isIOS) {
          return ['VT:copy=0', 'dav1d', 'FFmpeg'];
        } else if (Platform.isAndroid) {
          return ['AMediaCodec:copy=0', 'AMediaCodec', 'dav1d', 'FFmpeg'];
        } else {
          return ['VAAPI:copy=0', 'CUDA:copy=0', 'dav1d', 'FFmpeg'];
        }
    }
  }

  /// Returns the buffer string in MDK format: `duration_ms+packet_count`
  static String getEffectiveBufferString() {
    if (bufferPreset.value == BufferResiliencePreset.custom) {
      return '${customBufferMs.value}+${customBufferCount.value}';
    }
    return '${bufferPreset.value.durationMs}+${bufferPreset.value.packetCount}';
  }

  /// Generates the options map for `fvp.registerWith(options: ...)`
  static Map<String, dynamic> getFvpRegisterOptions() {
    final decoders = getEffectiveDecoders();
    final bufferStr = getEffectiveBufferString();

    return {
      'platforms': ['windows', 'linux', 'macos', 'android', 'ios'],
      'video.decoders': decoders,
      'lowLatency': lowLatency.value ? 1 : 0,
      'demux.format.allowed_extensions': 'ALL',
      'demux.format.protocol_whitelist': 'file,http,https,tcp,tls,crypto,data',
      'subtitleFontFile': 'assets/subfont.ttf',
      'player': {
        'sub-ass-override': 'scale',
        'sub-font-size': '32',
        'sub-scale': '1.0',
        'buffer': bufferStr,
        if (enableNetworkReconnect.value) ...{
          'avformat.reconnect': '1',
          'avformat.reconnect_streamed': '1',
          'avformat.reconnect_delay_max': reconnectDelayMax.value.toString(),
        },
        if (hardwareAudioClock.value) 'sync': 'audio',
      },
      'global': {
        'subtitle.fonts.file': 'assets://flutter_assets/assets/subfont.ttf',
        'subtitle.fonts.family': 'GoNotoKurrent',
      },
    };
  }

  /// Applies all player engine properties to an active [VideoPlayerController] instance.
  static void applyToController(VideoPlayerController controller) {
    try {
      final bufferStr = getEffectiveBufferString();
      controller.setProperty('buffer', bufferStr);

      if (enableNetworkReconnect.value) {
        controller.setProperty('avformat.reconnect', '1');
        controller.setProperty('avformat.reconnect_streamed', '1');
        controller.setProperty('avformat.reconnect_delay_max', reconnectDelayMax.value.toString());
      }

      if (hardwareAudioClock.value) {
        controller.setProperty('sync', 'audio');
      }

      if (lowLatency.value) {
        controller.setProperty('lowLatency', '1');
      } else {
        controller.setProperty('lowLatency', '0');
      }

      if (audioDelayDefault.value != 0.0) {
        controller.setProperty('audio-delay', audioDelayDefault.value.toString());
      }
    } catch (e) {
      debugPrint('[PlayerSettings] applyToController warning: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Mutation & Persistence
  // ───────────────────────────────────────────────────────────────────────────

  static Future<void> setDecoderPreset(DecoderPreset val) async {
    decoderPreset.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDecoderPreset, val.name);
    _notify();
  }

  static Future<void> setForceSoftwareDecoding(bool val) async {
    forceSoftwareDecoding.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyForceSoftwareDecoding, val);
    _notify();
  }

  static Future<void> setCustomDecoders(List<String> list) async {
    customDecoders.value = List.from(list);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCustomDecoders, list);
    _notify();
  }

  static Future<void> setBufferPreset(BufferResiliencePreset val) async {
    bufferPreset.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBufferPreset, val.name);
    _notify();
  }

  static Future<void> setCustomBuffer(int durationMs, int packetCount) async {
    customBufferMs.value = durationMs;
    customBufferCount.value = packetCount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomBufferMs, durationMs);
    await prefs.setInt(_keyCustomBufferCount, packetCount);
    _notify();
  }

  static Future<void> setEnableNetworkReconnect(bool val) async {
    enableNetworkReconnect.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableNetworkReconnect, val);
    _notify();
  }

  static Future<void> setReconnectDelayMax(int val) async {
    reconnectDelayMax.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReconnectDelayMax, val);
    _notify();
  }

  static Future<void> setAutoResyncOnStall(bool val) async {
    autoResyncOnStall.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoResyncOnStall, val);
    _notify();
  }

  static Future<void> setLowLatency(bool val) async {
    lowLatency.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLowLatency, val);
    _notify();
  }

  static Future<void> setHardwareAudioClock(bool val) async {
    hardwareAudioClock.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHardwareAudioClock, val);
    _notify();
  }

  static Future<void> setAudioDelayDefault(double val) async {
    audioDelayDefault.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyAudioDelayDefault, val);
    _notify();
  }

  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDecoderPreset);
    await prefs.remove(_keyForceSoftwareDecoding);
    await prefs.remove(_keyCustomDecoders);
    await prefs.remove(_keyBufferPreset);
    await prefs.remove(_keyCustomBufferMs);
    await prefs.remove(_keyCustomBufferCount);
    await prefs.remove(_keyEnableNetworkReconnect);
    await prefs.remove(_keyReconnectDelayMax);
    await prefs.remove(_keyAutoResyncOnStall);
    await prefs.remove(_keyLowLatency);
    await prefs.remove(_keyHardwareAudioClock);
    await prefs.remove(_keyAudioDelayDefault);

    decoderPreset.value = DecoderPreset.hardwareAuto;
    forceSoftwareDecoding.value = false;
    bufferPreset.value = Platform.isAndroid
        ? BufferResiliencePreset.highResilience
        : BufferResiliencePreset.standard;
    customBufferMs.value = 6000;
    customBufferCount.value = 300;
    enableNetworkReconnect.value = true;
    reconnectDelayMax.value = 5;
    autoResyncOnStall.value = true;
    lowLatency.value = false;
    hardwareAudioClock.value = true;
    audioDelayDefault.value = 0.0;
    customDecoders.value = _getDefaultDecodersForPreset(DecoderPreset.hardwareAuto);

    _notify();
  }

  static void _notify() {
    changeNotifier.value++;
  }
}
