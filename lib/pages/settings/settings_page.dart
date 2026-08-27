import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/addon/addon_manager.dart';
import '../../services/app_theme_service.dart';
import '../../services/debrid/debrid_service.dart';
import '../../services/glass_settings.dart';
import '../../services/trakt/trakt_service.dart';
import '../../services/simkl/simkl_service.dart';

import 'appearance_settings_page.dart';
import 'debrid_settings_page.dart';
import 'addons_settings_page.dart';
import 'trakt_settings_page.dart';
import 'simkl_settings_page.dart';
import 'updates_settings_page.dart';
import 'about_settings_page.dart';

import '../../widgets/common/animated_ambient_background.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _debrid = DebridService();
  bool _useDebrid = false;
  String _debridProvider = 'None';
  String? _appVersion;
  bool _traktConnected = false;
  bool _simklConnected = false;

  @override
  void initState() {
    super.initState();
    _loadOverviewState();
  }

  Future<void> _loadOverviewState() async {
    final useDebrid = await _debrid.getUseDebridForStreams();
    final provider = await _debrid.getSelectedService();
    final traktAuth = await TraktService.instance.isAuthenticated();
    final simklAuth = await SimklService.instance.isAuthenticated();
    final pkg = await PackageInfo.fromPlatform().catchError((_) => PackageInfo(
          appName: 'PlayTorrio',
          packageName: 'com.playtorrio',
          version: '1.0.0',
          buildNumber: '1',
        ));

    if (mounted) {
      setState(() {
        _useDebrid = useDebrid;
        _debridProvider = provider;
        _appVersion = pkg.version;
        _traktConnected = traktAuth;
        _simklConnected = simklAuth;
      });
    }
  }

  Future<void> _navigateTo(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    // Refresh badges when returning
    _loadOverviewState();
  }

  @override
  Widget build(BuildContext context) {
    final addonCount = AddonManager.instance.addons.length;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017).withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: AnimatedAmbientBackground(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 32 + bottomInset),
            children: [
              // Header Intro Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7C5CFF).withValues(alpha: 0.12),
                      const Color(0xFF00E5FF).withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF7C5CFF).withValues(alpha: 20 / 100),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C5CFF).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Color(0xFF7C5CFF),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preferences & Configuration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Manage streaming providers, addons, UI effects, and account sync.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.5),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section Label
              Text(
                'CATEGORIES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),

              // 1. Appearance & Interface
              ValueListenableBuilder<bool>(
                valueListenable: GlassSettings.enabled,
                builder: (context, glassEnabled, _) {
                  return ValueListenableBuilder<AppThemePalette>(
                    valueListenable: AppThemeService.currentPalette,
                    builder: (context, currentPalette, _) {
                      return _SettingsCategoryTile(
                        icon: Icons.palette_rounded,
                        iconColor: currentPalette.primaryColor,
                        title: 'Appearance & Interface',
                        subtitle: 'Liquid Glass setup, color themes, and Home Page UI',
                        badgeText: glassEnabled ? '${currentPalette.name} · Glass ON' : currentPalette.name,
                        badgeColor: currentPalette.primaryColor,
                        onTap: () => _navigateTo(const AppearanceSettingsPage()),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 12),

              // 2. Debrid & Cloud Streaming
              _SettingsCategoryTile(
                icon: Icons.cloud_download_rounded,
                iconColor: const Color(0xFF00E5FF),
                title: 'Debrid & Cloud Streaming',
                subtitle: 'Real-Debrid, TorBox, AllDebrid, Premiumize & Debrid-Link',
                badgeText: _useDebrid
                    ? (_debridProvider != 'None' ? _debridProvider : 'Active')
                    : 'Disabled',
                badgeColor: _useDebrid ? const Color(0xFF00E5FF) : Colors.white38,
                onTap: () => _navigateTo(const DebridSettingsPage()),
              ),

              const SizedBox(height: 12),

              // 3. Metadata & Catalogs (Addons)
              _SettingsCategoryTile(
                icon: Icons.extension_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Metadata Addons',
                subtitle: 'Stremio catalogs, movie/series metadata providers',
                badgeText: '$addonCount Installed',
                badgeColor: const Color(0xFF10B981),
                onTap: () => _navigateTo(const AddonsSettingsPage()),
              ),

              const SizedBox(height: 12),

              // 4. Trakt Sync
              _SettingsCategoryTile(
                icon: Icons.movie_filter_rounded,
                iconColor: const Color(0xFFED1C24),
                title: 'Trakt.tv Sync',
                subtitle: 'Cross-device watchlist, history & playback synchronization',
                badgeText: _traktConnected ? 'Connected' : 'Offline',
                badgeColor: _traktConnected ? const Color(0xFFED1C24) : Colors.white38,
                onTap: () => _navigateTo(const TraktSettingsPage()),
              ),

              const SizedBox(height: 12),

              // 5. Simkl Sync
              _SettingsCategoryTile(
                icon: Icons.tv_rounded,
                iconColor: const Color(0xFF00ADFF),
                title: 'Simkl Sync',
                subtitle: 'Cross-device Movies, TV & Anime synchronization',
                badgeText: _simklConnected ? 'Connected' : 'Offline',
                badgeColor: _simklConnected ? const Color(0xFF00ADFF) : Colors.white38,
                onTap: () => _navigateTo(const SimklSettingsPage()),
              ),

              const SizedBox(height: 12),

              // 5. App Updates & System
              _SettingsCategoryTile(
                icon: Icons.system_update_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'App Updates',
                subtitle: 'Check for latest software versions and patches',
                badgeText: _appVersion != null ? 'v$_appVersion' : 'Check',
                badgeColor: const Color(0xFFF59E0B),
                onTap: () => _navigateTo(const UpdatesSettingsPage()),
              ),

              const SizedBox(height: 12),

              // 6. About PlayTorrio
              _SettingsCategoryTile(
                icon: Icons.info_outline_rounded,
                iconColor: Colors.white70,
                title: 'About PlayTorrio',
                subtitle: 'Architecture, video engine, and credits',
                onTap: () => _navigateTo(const AboutSettingsPage()),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Category Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCategoryTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _SettingsCategoryTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF12151E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              // Icon Container with subtle tinted background
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? iconColor).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: badgeColor ?? iconColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Chevron right
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
