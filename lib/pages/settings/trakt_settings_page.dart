import 'package:flutter/material.dart';
import '../../services/trakt/trakt_auth_service.dart';
import '../../services/trakt/trakt_sync_service.dart';

class TraktSettingsPage extends StatelessWidget {
  const TraktSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final traktAuth = TraktAuthService();

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Account & Trakt Sync',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // Header description
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Connect your Trakt.tv account to seamlessly synchronize your watch history, watchlist, and playback progress across all your devices.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ),

              // Trakt Status & Connect Card
              ValueListenableBuilder<bool>(
                valueListenable: traktAuth.isLoggedIn,
                builder: (context, loggedIn, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: traktAuth.isLoading,
                    builder: (context, loading, _) {
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF12151E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: loggedIn
                                ? const Color(0xFFED1C24).withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFED1C24).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.sync_rounded, color: Color(0xFFED1C24), size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Trakt.tv',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (loggedIn ? const Color(0xFF10B981) : Colors.white24).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              loggedIn ? 'CONNECTED' : 'DISCONNECTED',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: loggedIn ? const Color(0xFF10B981) : Colors.white54,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        loggedIn
                                            ? 'Your account is linked and ready to sync'
                                            : 'Sign in with Trakt to activate cloud sync',
                                        style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (loggedIn)
                                  OutlinedButton(
                                    onPressed: loading ? null : () => traktAuth.logout(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                    child: const Text('Disconnect', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: loading ? null : () => traktAuth.authorize(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFED1C24),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                    child: loading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Connect',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                          ),
                                  ),
                              ],
                            ),
                            if (loggedIn) ...[
                              const SizedBox(height: 16),
                              Divider(color: Colors.white.withValues(alpha: 0.06)),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await TraktSyncService.syncDown();
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Watchlist synced with Trakt!'),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.sync_rounded, size: 18),
                                  label: const Text('Sync Watchlist Now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),

              // Trakt Features & Benefits
              Text(
                'TRAKT SYNC FEATURES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),

              _buildBenefitTile(
                icon: Icons.bookmark_added_rounded,
                title: 'Cross-Device Watchlist',
                subtitle: 'Add movies and series to your watchlist on any device and access them in PlayTorrio.',
              ),
              const SizedBox(height: 10),
              _buildBenefitTile(
                icon: Icons.history_rounded,
                title: 'Playback History',
                subtitle: 'Automatically keep track of completed episodes and movies.',
              ),
              const SizedBox(height: 10),
              _buildBenefitTile(
                icon: Icons.recommend_rounded,
                title: 'Personalized Recommendations',
                subtitle: 'Get smarter recommendations based on your Trakt community ratings and history.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFED1C24).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFED1C24), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
