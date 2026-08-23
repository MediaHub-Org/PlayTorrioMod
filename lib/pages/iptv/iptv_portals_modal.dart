import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/iptv/iptv_controller.dart';
import '../../utils/route_transitions.dart';
import 'iptv_portal_browser_page.dart';

class IptvPortalsModal extends StatefulWidget {
  const IptvPortalsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => const IptvPortalsModal(),
    );
  }

  @override
  State<IptvPortalsModal> createState() => _IptvPortalsModalState();
}

class _IptvPortalsModalState extends State<IptvPortalsModal>
    with SingleTickerProviderStateMixin {
  final _ctrl = IptvController.instance;
  late final TabController _tabController;

  // Add Portal Controllers
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // M3U Controllers
  final _m3uNameCtrl = TextEditingController();
  final _m3uUrlCtrl = TextEditingController();

  // JSON Import Controller
  final _jsonCtrl = TextEditingController();

  bool _showAddForm = false;
  bool _showM3uForm = false;
  bool _showJsonImport = false;

  bool _isPortalsEditMode = false;
  final Set<String> _selectedPortalKeys = {};

  bool _isM3uEditMode = false;
  final Set<String> _selectedM3uIds = {};

  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _m3uNameCtrl.dispose();
    _m3uUrlCtrl.dispose();
    _jsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAddPortal() async {
    final success = await _ctrl.addManual(
      url: _urlCtrl.text,
      username: _userCtrl.text,
      password: _passCtrl.text,
    );
    if (success) {
      _urlCtrl.clear();
      _userCtrl.clear();
      _passCtrl.clear();
      setState(() => _showAddForm = false);
    }
  }

  Future<void> _submitAddM3u() async {
    if (_m3uUrlCtrl.text.trim().isEmpty) return;
    await _ctrl.addM3uFromUrl(_m3uNameCtrl.text, _m3uUrlCtrl.text.trim());
    _m3uNameCtrl.clear();
    _m3uUrlCtrl.clear();
    setState(() => _showM3uForm = false);
  }

  Future<void> _submitJsonImport() async {
    if (_jsonCtrl.text.trim().isEmpty) return;
    await _ctrl.importFromJsonString(_jsonCtrl.text.trim());
    _jsonCtrl.clear();
    setState(() => _showJsonImport = false);
  }

  Future<void> _deleteSelectedPortals() async {
    if (_selectedPortalKeys.isEmpty) return;
    final count = _selectedPortalKeys.length;
    final toDelete = Set<String>.from(_selectedPortalKeys);
    setState(() {
      _selectedPortalKeys.clear();
      _isPortalsEditMode = false;
    });
    await _ctrl.deletePortalsByKeys(toDelete);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $count portal${count == 1 ? "" : "s"}'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF1E2235),
        ),
      );
    }
  }

  Future<void> _deleteAllPortals() async {
    final count = _ctrl.verified.length;
    setState(() {
      _selectedPortalKeys.clear();
      _isPortalsEditMode = false;
    });
    await _ctrl.deleteAllPortals();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed all $count portals'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF1E2235),
        ),
      );
    }
  }

  Future<void> _deleteSelectedM3u() async {
    if (_selectedM3uIds.isEmpty) return;
    final count = _selectedM3uIds.length;
    final toDelete = Set<String>.from(_selectedM3uIds);
    setState(() {
      _selectedM3uIds.clear();
      _isM3uEditMode = false;
    });
    for (final id in toDelete) {
      await _ctrl.deleteM3uPlaylist(id);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $count playlist${count == 1 ? "" : "s"}'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF1E2235),
        ),
      );
    }
  }

  Future<void> _deleteAllM3u() async {
    final count = _ctrl.m3uPlaylists.length;
    setState(() {
      _selectedM3uIds.clear();
      _isM3uEditMode = false;
    });
    await _ctrl.deleteAllM3uPlaylists();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed all $count playlists'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF1E2235),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Dialog(
          backgroundColor: const Color(0xFF0C0E15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C5CFF).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.settings_input_antenna_rounded,
                            color: Color(0xFF7C5CFF), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'IPTV Portals & Playlists',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF7C5CFF),
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  tabs: [
                    Tab(text: 'Xtream Panels (${_ctrl.verified.length})'),
                    Tab(text: 'M3U Playlists (${_ctrl.m3uPlaylists.length})'),
                  ],
                ),

                const Divider(color: Colors.white10, height: 1),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPortalsTab(),
                      _buildM3uTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortalsTab() {
    final allSelected = _ctrl.verified.isNotEmpty && _selectedPortalKeys.length == _ctrl.verified.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Buttons Bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5CFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: _ctrl.isScraping
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.radar_rounded, size: 16, color: Colors.white),
                label: Text(
                  _ctrl.isScraping ? 'Scraping Reddit…' : 'Scrape Reddit Portals',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                onPressed: _ctrl.isScraping ? null : _ctrl.scrape,
              ),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Portal', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () => setState(() {
                  _showAddForm = !_showAddForm;
                  _showJsonImport = false;
                }),
              ),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('Import JSON', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () => setState(() {
                  _showJsonImport = !_showJsonImport;
                  _showAddForm = false;
                }),
              ),

              if (_ctrl.verified.isNotEmpty)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isPortalsEditMode ? const Color(0xFF00D2EF) : Colors.white,
                    side: BorderSide(
                      color: _isPortalsEditMode ? const Color(0xFF00D2EF) : Colors.white.withValues(alpha: 0.2),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: Icon(_isPortalsEditMode ? Icons.edit_off_rounded : Icons.edit_rounded, size: 16),
                  label: Text(_isPortalsEditMode ? 'Done' : 'Manage', style: const TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    setState(() {
                      _isPortalsEditMode = !_isPortalsEditMode;
                      if (!_isPortalsEditMode) _selectedPortalKeys.clear();
                    });
                  },
                ),
            ],
          ),

          // Selection Toolbar for Portals
          if (_isPortalsEditMode && _ctrl.verified.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C5CFF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7C5CFF).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                      size: 17,
                      color: const Color(0xFF00D2EF),
                    ),
                    label: Text(
                      allSelected ? 'Deselect All' : 'Select All',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          _selectedPortalKeys.clear();
                        } else {
                          _selectedPortalKeys.clear();
                          _selectedPortalKeys.addAll(_ctrl.verified.map((v) => v.key));
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${_selectedPortalKeys.length}/${_ctrl.verified.length})',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  // Delete Selected
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.delete_rounded, size: 14),
                    label: Text(
                      'Delete (${_selectedPortalKeys.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _selectedPortalKeys.isEmpty ? null : _deleteSelectedPortals,
                  ),
                  const SizedBox(width: 6),
                  // Delete All
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _deleteAllPortals,
                    child: const Text('Delete All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],

          if (_ctrl.statusText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _ctrl.statusText,
              style: const TextStyle(color: Color(0xFF00D2EF), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],

          // Add Manual Portal Form
          if (_showAddForm) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Xtream Codes Portal',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _urlCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Server URL (e.g. http://example.com:8080)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _userCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _passCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_ctrl.addError != null) ...[
                    const SizedBox(height: 6),
                    Text(_ctrl.addError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C5CFF)),
                      onPressed: _ctrl.isAdding ? null : _submitAddPortal,
                      child: _ctrl.isAdding
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Verify & Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // JSON Bulk Import Form
          if (_showJsonImport) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Paste JSON Portal List',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _jsonCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: '[{"url": "http://...", "username": "...", "password": "..."}, ...]',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C5CFF)),
                      onPressed: _ctrl.isImporting ? null : _submitJsonImport,
                      child: const Text('Import All'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // List of Portals
          Expanded(
            child: _ctrl.verified.isEmpty
                ? const Center(
                    child: Text('No verified portals. Tap "Scrape Reddit Portals" to auto-discover.',
                        style: TextStyle(color: Colors.white54)),
                  )
                : ListView.separated(
                    itemCount: _ctrl.verified.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = _ctrl.verified[index];
                      final isFav = _ctrl.isFavoritePortal(p.key);
                      final isSelected = _selectedPortalKeys.contains(p.key);

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTapDown: (details) => _tapPosition = details.globalPosition,
                          onTap: () {
                            if (_isPortalsEditMode) {
                              setState(() {
                                if (isSelected) {
                                  _selectedPortalKeys.remove(p.key);
                                } else {
                                  _selectedPortalKeys.add(p.key);
                                }
                              });
                            } else {
                              final tapPos = _tapPosition;
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                LiquidRevealRoute(
                                  page: IptvPortalBrowserPage(portal: p),
                                  tapPosition: tapPos,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF7C5CFF).withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF7C5CFF)
                                    : Colors.white.withValues(alpha: 0.08),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_isPortalsEditMode)
                                  Container(
                                    width: 24,
                                    height: 24,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF7C5CFF) : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF7C5CFF) : Colors.white38,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                                        : null,
                                  )
                                else ...[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name.isNotEmpty ? p.name : p.portal.url,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      Text(
                                        '${p.portal.url} · Exp: ${p.expiry} · Conn: ${p.activeConnections}/${p.maxConnections}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 18),
                                  tooltip: 'Copy Login (url:username:password)',
                                  onPressed: () {
                                    final text = '${p.portal.url}:${p.portal.username}:${p.portal.password}';
                                    Clipboard.setData(ClipboardData(text: text));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Copied: $text'),
                                        duration: const Duration(seconds: 2),
                                        backgroundColor: const Color(0xFF1E2235),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: isFav ? const Color(0xFFFFC107) : Colors.white38,
                                    size: 20,
                                  ),
                                  onPressed: () => _ctrl.toggleFavoritePortal(p.key),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () => _ctrl.deletePortalsByKeys({p.key}),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildM3uTab() {
    final allSelected = _ctrl.m3uPlaylists.isNotEmpty && _selectedM3uIds.length == _ctrl.m3uPlaylists.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5CFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.playlist_add_rounded, size: 18, color: Colors.white),
                label: const Text('Add M3U URL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onPressed: () => setState(() => _showM3uForm = !_showM3uForm),
              ),

              if (_ctrl.m3uPlaylists.isNotEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isM3uEditMode ? const Color(0xFF00D2EF) : Colors.white,
                    side: BorderSide(
                      color: _isM3uEditMode ? const Color(0xFF00D2EF) : Colors.white.withValues(alpha: 0.2),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: Icon(_isM3uEditMode ? Icons.edit_off_rounded : Icons.edit_rounded, size: 16),
                  label: Text(_isM3uEditMode ? 'Done' : 'Manage', style: const TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    setState(() {
                      _isM3uEditMode = !_isM3uEditMode;
                      if (!_isM3uEditMode) _selectedM3uIds.clear();
                    });
                  },
                ),
              ],
            ],
          ),

          // Selection Toolbar for M3U
          if (_isM3uEditMode && _ctrl.m3uPlaylists.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C5CFF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7C5CFF).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                      size: 17,
                      color: const Color(0xFF00D2EF),
                    ),
                    label: Text(
                      allSelected ? 'Deselect All' : 'Select All',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          _selectedM3uIds.clear();
                        } else {
                          _selectedM3uIds.clear();
                          _selectedM3uIds.addAll(_ctrl.m3uPlaylists.map((pl) => pl.id));
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${_selectedM3uIds.length}/${_ctrl.m3uPlaylists.length})',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  // Delete Selected
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.delete_rounded, size: 14),
                    label: Text(
                      'Delete (${_selectedM3uIds.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _selectedM3uIds.isEmpty ? null : _deleteSelectedM3u,
                  ),
                  const SizedBox(width: 6),
                  // Delete All
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _deleteAllM3u,
                    child: const Text('Delete All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],

          if (_showM3uForm) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add M3U Playlist Subscription',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _m3uNameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Playlist Name',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _m3uUrlCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'M3U / M3U8 URL',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C5CFF)),
                      onPressed: _ctrl.isM3uLoading ? null : _submitAddM3u,
                      child: _ctrl.isM3uLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Fetch & Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          Expanded(
            child: _ctrl.m3uPlaylists.isEmpty
                ? const Center(
                    child: Text('No M3U playlists saved.', style: TextStyle(color: Colors.white54)),
                  )
                : ListView.separated(
                    itemCount: _ctrl.m3uPlaylists.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final pl = _ctrl.m3uPlaylists[index];
                      final isSelected = _selectedM3uIds.contains(pl.id);

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTapDown: (details) => _tapPosition = details.globalPosition,
                          onTap: () {
                            if (_isM3uEditMode) {
                              setState(() {
                                if (isSelected) {
                                  _selectedM3uIds.remove(pl.id);
                                } else {
                                  _selectedM3uIds.add(pl.id);
                                }
                              });
                            } else {
                              final tapPos = _tapPosition;
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                LiquidRevealRoute(
                                  page: IptvPortalBrowserPage(m3uPlaylist: pl),
                                  tapPosition: tapPos,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF7C5CFF).withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF7C5CFF)
                                    : Colors.white.withValues(alpha: 0.08),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_isM3uEditMode)
                                  Container(
                                    width: 24,
                                    height: 24,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF7C5CFF) : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF7C5CFF) : Colors.white38,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                                        : null,
                                  )
                                else ...[
                                  const Icon(Icons.queue_music_rounded, color: Color(0xFF7C5CFF), size: 20),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pl.name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                                      ),
                                      Text(
                                        '${pl.channels.length} channels ${pl.sourceUrl != null ? '· ${pl.sourceUrl!}' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 18),
                                  tooltip: 'Copy Playlist URL',
                                  onPressed: () {
                                    final text = pl.sourceUrl ?? '';
                                    if (text.isNotEmpty) {
                                      Clipboard.setData(ClipboardData(text: text));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Copied: $text'),
                                          duration: const Duration(seconds: 2),
                                          backgroundColor: const Color(0xFF1E2235),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () => _ctrl.deleteM3uPlaylist(pl.id),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
