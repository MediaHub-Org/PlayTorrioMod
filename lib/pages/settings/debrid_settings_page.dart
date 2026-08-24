import 'package:flutter/material.dart';
import '../../services/debrid/debrid_service.dart';

class DebridSettingsPage extends StatefulWidget {
  const DebridSettingsPage({super.key});

  @override
  State<DebridSettingsPage> createState() => _DebridSettingsPageState();
}

class _DebridSettingsPageState extends State<DebridSettingsPage> {
  final _debrid = DebridService();
  bool _useDebrid = false;
  String _selectedService = 'None';
  String? _rdUser;

  final _rdKeyCtrl = TextEditingController();
  final _torboxKeyCtrl = TextEditingController();
  final _alldebridKeyCtrl = TextEditingController();
  final _premiumizeKeyCtrl = TextEditingController();
  final _debridlinkKeyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final useDebrid = await _debrid.getUseDebridForStreams();
    final service = await _debrid.getSelectedService();
    final rd = await _debrid.realDebrid.getToken() ?? '';
    final tb = await _debrid.torBox.getKey() ?? '';
    final ad = await _debrid.allDebrid.getKey() ?? '';
    final pm = await _debrid.premiumize.getKey() ?? '';
    final dl = await _debrid.debridLink.getKey() ?? '';

    _rdKeyCtrl.text = rd;
    _torboxKeyCtrl.text = tb;
    _alldebridKeyCtrl.text = ad;
    _premiumizeKeyCtrl.text = pm;
    _debridlinkKeyCtrl.text = dl;

    if (rd.isNotEmpty) {
      final user = await _debrid.realDebrid.verifyToken(rd);
      if (user != null) {
        _rdUser = user['username'] as String?;
      }
    }

    if (mounted) {
      setState(() {
        _useDebrid = useDebrid;
        _selectedService = service;
      });
    }
  }

  @override
  void dispose() {
    _rdKeyCtrl.dispose();
    _torboxKeyCtrl.dispose();
    _alldebridKeyCtrl.dispose();
    _premiumizeKeyCtrl.dispose();
    _debridlinkKeyCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF00E5FF),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.black,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const services = [
      'None',
      'Real-Debrid',
      'TorBox',
      'AllDebrid',
      'Premiumize',
      'Debrid-Link',
    ];

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
          'Debrid & Cloud Streaming',
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
                  'Stream torrents and magnet links instantly through high-speed cloud debrid providers without local peer-to-peer downloading.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ),

              // Master Debrid Toggle Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _useDebrid
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
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
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.cloud_download_rounded,
                            color: Color(0xFF00E5FF),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Use Debrid for Streams',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Route torrent links through cloud servers',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch.adaptive(
                          value: _useDebrid,
                          activeColor: const Color(0xFF00E5FF),
                          onChanged: (val) async {
                            setState(() => _useDebrid = val);
                            await _debrid.saveUseDebridForStreams(val);
                            if (val) {
                              final service = _selectedService;
                              if (service == 'None') {
                                _showSnack(
                                  'Select an active Debrid provider and save your API key below.',
                                  isError: true,
                                );
                              } else {
                                final hasKey = await _debrid.hasKeyForService(service);
                                if (!hasKey) {
                                  _showSnack(
                                    '$service has no API key saved. Please enter and save your key below.',
                                    isError: true,
                                  );
                                } else {
                                  _showSnack('Debrid streaming activated via $service');
                                }
                              }
                            } else {
                              _showSnack('Debrid streaming disabled. Using local engine.');
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'When enabled, all torrents from PlayTorrio and Stremio addons are resolved exclusively through your active Debrid provider without touching the local torrent engine.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Active Provider Selector
              Text(
                'ACTIVE PROVIDER',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Default Debrid Provider',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PlayTorrio will send requests to this provider when streaming.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: services.contains(_selectedService) ? _selectedService : 'None',
                      dropdownColor: const Color(0xFF151822),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0D1017),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      items: services.map((s) {
                        return DropdownMenuItem<String>(
                          value: s,
                          child: Row(
                            children: [
                              Icon(
                                s == 'None' ? Icons.block_rounded : Icons.flash_on_rounded,
                                size: 16,
                                color: s == 'None' ? Colors.white38 : const Color(0xFF00E5FF),
                              ),
                              const SizedBox(width: 8),
                              Text(s),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _selectedService = val);
                          await _debrid.saveSelectedService(val);
                          if (val != 'None') {
                            final hasKey = await _debrid.hasKeyForService(val);
                            if (!hasKey) {
                              _showSnack(
                                '$val selected, but has no API key saved yet. Please enter and save your key below.',
                              );
                              return;
                            }
                          }
                          _showSnack('Active Debrid service set to $val');
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Provider API Keys
              Text(
                'PROVIDER CREDENTIALS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),

              // Real-Debrid Card
              _buildProviderCard(
                name: 'Real-Debrid',
                subtitle: _rdUser != null
                    ? 'Logged in as $_rdUser'
                    : 'Get token from real-debrid.com/apitoken',
                statusBadge: _rdUser != null ? 'Verified' : null,
                badgeColor: const Color(0xFF10B981),
                controller: _rdKeyCtrl,
                isActive: _selectedService == 'Real-Debrid',
                onSave: () async {
                  final key = _rdKeyCtrl.text.trim();
                  await _debrid.realDebrid.saveToken(key);
                  if (key.isNotEmpty) {
                    if (_selectedService == 'None') {
                      setState(() => _selectedService = 'Real-Debrid');
                      await _debrid.saveSelectedService('Real-Debrid');
                    }
                    final user = await _debrid.realDebrid.verifyToken(key);
                    setState(() => _rdUser = user?['username'] as String?);
                    if (user != null) {
                      _showSnack('Real-Debrid verified: Logged in as ${user['username']}');
                    } else {
                      _showSnack('Real-Debrid token saved.');
                    }
                  } else {
                    setState(() => _rdUser = null);
                    _showSnack('Real-Debrid token cleared.');
                  }
                },
              ),
              const SizedBox(height: 12),

              // TorBox Card
              _buildProviderCard(
                name: 'TorBox',
                subtitle: 'Get key from torbox.app/settings',
                controller: _torboxKeyCtrl,
                isActive: _selectedService == 'TorBox',
                onSave: () async {
                  final key = _torboxKeyCtrl.text.trim();
                  await _debrid.torBox.saveKey(key);
                  if (key.isNotEmpty && _selectedService == 'None') {
                    setState(() => _selectedService = 'TorBox');
                    await _debrid.saveSelectedService('TorBox');
                  }
                  _showSnack(
                    key.isNotEmpty ? 'TorBox API key saved and activated' : 'TorBox API key cleared',
                  );
                },
              ),
              const SizedBox(height: 12),

              // AllDebrid Card
              _buildProviderCard(
                name: 'AllDebrid',
                subtitle: 'Get key from alldebrid.com/apikeys',
                controller: _alldebridKeyCtrl,
                isActive: _selectedService == 'AllDebrid',
                onSave: () async {
                  final key = _alldebridKeyCtrl.text.trim();
                  await _debrid.allDebrid.saveKey(key);
                  if (key.isNotEmpty && _selectedService == 'None') {
                    setState(() => _selectedService = 'AllDebrid');
                    await _debrid.saveSelectedService('AllDebrid');
                  }
                  _showSnack(
                    key.isNotEmpty ? 'AllDebrid API key saved and activated' : 'AllDebrid API key cleared',
                  );
                },
              ),
              const SizedBox(height: 12),

              // Premiumize Card
              _buildProviderCard(
                name: 'Premiumize',
                subtitle: 'Get key from premiumize.me/account',
                controller: _premiumizeKeyCtrl,
                isActive: _selectedService == 'Premiumize',
                onSave: () async {
                  final key = _premiumizeKeyCtrl.text.trim();
                  await _debrid.premiumize.saveKey(key);
                  if (key.isNotEmpty && _selectedService == 'None') {
                    setState(() => _selectedService = 'Premiumize');
                    await _debrid.saveSelectedService('Premiumize');
                  }
                  _showSnack(
                    key.isNotEmpty ? 'Premiumize API key saved and activated' : 'Premiumize API key cleared',
                  );
                },
              ),
              const SizedBox(height: 12),

              // Debrid-Link Card
              _buildProviderCard(
                name: 'Debrid-Link',
                subtitle: 'Get key from debrid-link.com/webapp/apikey',
                controller: _debridlinkKeyCtrl,
                isActive: _selectedService == 'Debrid-Link',
                onSave: () async {
                  final key = _debridlinkKeyCtrl.text.trim();
                  await _debrid.debridLink.saveKey(key);
                  if (key.isNotEmpty && _selectedService == 'None') {
                    setState(() => _selectedService = 'Debrid-Link');
                    await _debrid.saveSelectedService('Debrid-Link');
                  }
                  _showSnack(
                    key.isNotEmpty ? 'Debrid-Link API key saved and activated' : 'Debrid-Link API key cleared',
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard({
    required String name,
    required String subtitle,
    required TextEditingController controller,
    required VoidCallback onSave,
    bool isActive = false,
    String? statusBadge,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
              ],
              if (statusBadge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? const Color(0xFF10B981)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: badgeColor ?? const Color(0xFF10B981),
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
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Paste API Key / Token',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0D1017),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
