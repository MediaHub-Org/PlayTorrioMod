import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fvp/fvp.dart' as fvp;

import 'package:window_manager/window_manager.dart';

import './pages/home/home_page.dart';
import './services/addon/addon_manager.dart';
import './services/app_theme_service.dart';
import './services/app_updater_service.dart';
import './services/continue_watching/continue_watching_service.dart';
import './services/glass_settings.dart';
import './services/audiobook/audiobook_settings.dart';
import './services/home_page_settings.dart';
import './services/iptv/iptv_controller.dart';
import './services/iptv/iptv_settings.dart';
import './services/manga/manga_settings.dart';
import './services/music/music_settings.dart';
import './services/music/qobuz_music_service.dart';
import './services/my_list/my_list_service.dart';
import './services/stream/local_stream_proxy.dart';
import './services/download/download_service.dart';
import './services/env_service.dart';
import './services/window/window_service.dart';
import './widgets/update_dialog.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await WindowService.instance.initialize();
  }
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await EnvService.initialize();
  fvp.registerWith(options: {
    'platforms': ['windows', 'linux', 'macos', 'android', 'ios'],
    'video.decoders': Platform.isWindows
        ? ['MFT:d3d=11:copy=0', 'D3D11:copy=0', 'CUDA:copy=0', 'DXVA', 'dav1d', 'FFmpeg']
        : Platform.isMacOS || Platform.isIOS
            ? ['VT:copy=0', 'dav1d', 'FFmpeg']
            : Platform.isAndroid
                ? ['AMediaCodec:copy=0', 'dav1d', 'FFmpeg']
                : ['VAAPI:copy=0', 'CUDA:copy=0', 'dav1d', 'FFmpeg'],
    'lowLatency': 0,
    'demux.format.allowed_extensions': 'ALL',
    'demux.format.protocol_whitelist': 'file,http,https,tcp,tls,crypto,data',
    'subtitleFontFile': 'assets/subfont.ttf',
    'player': {
      'sub-ass-override': 'scale',
      'sub-font-size': '32',
      'sub-scale': '1.0',
    },
    'global': {
      'subtitle.fonts.file': 'assets://flutter_assets/assets/subfont.ttf',
      'subtitle.fonts.family': 'GoNotoKurrent',
    },
  });
  await Future.wait([
    AddonManager.instance.initialize(),
    AppThemeService.initialize(),
    AudiobookSettings.initialize(),
    ContinueWatchingService.initialize(),
    GlassSettings.initialize(),
    HomePageSettings.initialize(),
    IptvController.instance.init(),
    IptvSettings.initialize(),
    MangaSettings.initialize(),
    MusicSettings.initialize(),
    QobuzMusicService.instance.initialize(),
    MyListService.initialize(),
    LocalStreamProxy.instance.start(),
    DownloadService.instance.initialize(),
  ]);
  runApp(const PlayTorrioApp());
}

class PlayTorrioApp extends StatefulWidget {
  const PlayTorrioApp({super.key});

  @override
  State<PlayTorrioApp> createState() => _PlayTorrioAppState();
}

class _PlayTorrioAppState extends State<PlayTorrioApp>
    with WidgetsBindingObserver {
  static bool _hasCheckedInitialUpdate = false;
  static bool _isShowingUpdateDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCheckedInitialUpdate) {
        _hasCheckedInitialUpdate = true;
        _checkForUpdates();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdates();
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isShowingUpdateDialog) return;
    try {
      final updater = AppUpdaterService();
      final updateInfo = await updater.checkForUpdates();
      final context = navigatorKey.currentContext;

      if (updateInfo != null && context != null && context.mounted) {
        _isShowingUpdateDialog = true;
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => UpdateDialog(updateInfo: updateInfo),
        );
        _isShowingUpdateDialog = false;
      }
    } catch (e) {
      _isShowingUpdateDialog = false;
      debugPrint('Error checking for app updates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, palette, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'PlayTorrio',
          debugShowCheckedModeBanner: false,
          theme: AppThemeService.createThemeData(palette),
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            overscroll: false,
          ),
          home: const HomePage(),
        );
      },
    );
  }
}

