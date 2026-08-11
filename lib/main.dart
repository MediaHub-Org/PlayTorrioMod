import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fvp/fvp.dart' as fvp;
import 'package:libtorrent_flutter/libtorrent_flutter.dart';

import './pages/home/home_page.dart';
import './services/addon/addon_manager.dart';
import './services/glass_settings.dart';
import './services/my_list/my_list_service.dart';
import './services/trakt/trakt_auth_service.dart';
import './services/trakt/trakt_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  fvp.registerWith();
  await LibtorrentFlutter.init();
  await Future.wait([
    AddonManager.instance.initialize(),
    GlassSettings.initialize(),
    MyListService.initialize(),
    TraktAuthService().initialize(),
    TraktSyncService.initialize(),
  ]);
  runApp(const PlayTorrioApp());
}

class PlayTorrioApp extends StatelessWidget {
  const PlayTorrioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlayTorrio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080A0F),
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C5CFF),
      ),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
      home: const HomePage(),
    );
  }
}
