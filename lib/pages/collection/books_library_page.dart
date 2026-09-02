import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../services/books/book_library_service.dart';
import '../../services/books/book_progress_service.dart';
import '../../services/books/books_service.dart';
import '../../services/manga/manga_service.dart';
import '../../widgets/common/library_sections.dart';
import '../../widgets/common/library_tabs.dart';
import '../manga/manga_details_page.dart';
import '../manga/manga_reader_page.dart';
import '../read/book_reader_page.dart';
import '../../utils/navigation/route_transitions.dart';

/// The Read hub's Library.
///
/// Carries the same four tabs as every other hub (see [LibrarySection]).
/// Books and manga are a sub-tab inside Saved rather than two top-level
/// tabs. Audiobooks used to be a third here too, before Audiobooks itself
/// moved to Listen (paired with Podcasts) -- its saved/downloads/history now
/// live in Listen's own Library instead.
class BooksLibraryPage extends StatefulWidget {
  const BooksLibraryPage({super.key});

  @override
  State<BooksLibraryPage> createState() => _BooksLibraryPageState();
}

class _BooksLibraryPageState extends State<BooksLibraryPage> {
  final MangaService _mangaService = MangaService();
  List<Manga> _likedManga = [];
  bool _loadingManga = true;

  List<_HistoryEntry> _historyEntries = [];
  bool _loadingHistory = true;

  /// Saved > Liked type filter chip -- not a sub-tab/page, matching Watch's
  /// own Saved page (type is a filter, status is the actual navigation).
  String _likedTypeFilter = 'all';

  /// Anything past this counts as finished, so it drops out of Continue and
  /// stays only in History. Readers rarely close a book on the exact last
  /// page, so the threshold is short of 100%.
  static const double _finishedAt = 0.95;

  List<_HistoryEntry> get _inProgressEntries => _historyEntries
      .where((e) => e.progress != null && e.progress! < _finishedAt)
      .toList();

  @override
  void initState() {
    super.initState();
    BookLibraryService.instance.init();
    _loadLikedManga();
    _loadHistory();
  }

  Future<void> _openLikedBook(BookResult book) async {
    final progress = await BookProgressService.instance.loadAll();
    if (!mounted) return;
    final entry = progress
        .where((p) => p.book.editionId == book.editionId)
        .firstOrNull;
    if (entry != null &&
        File(entry.filePath).existsSync() &&
        File(entry.filePath).lengthSync() > 1000) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => openBookReaderFor(
            file: File(entry.filePath),
            title: book.title,
            bookResult: book,
            initialChapter: entry.chapter,
          ),
        ),
      );
      _loadHistory();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search for "${book.title}" in Books to download it.'),
        ),
      );
    }
  }

  Future<void> _loadLikedManga() async {
    final liked = await _mangaService.getLikedManga();
    if (mounted) {
      setState(() {
        _likedManga = liked;
        _loadingManga = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    final results = await Future.wait([
      BookProgressService.instance.loadAll(),
      _mangaService.getReadingHistory(),
    ]);
    final books = results[0] as List<BookProgress>;
    final manga = results[1] as List<Map<String, dynamic>>;

    final entries = <_HistoryEntry>[
      for (final b in books) _historyEntryFromBook(b),
      for (final m in manga) _historyEntryFromManga(m),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (mounted) {
      setState(() {
        _historyEntries = entries;
        _loadingHistory = false;
      });
    }
  }

  _HistoryEntry _historyEntryFromBook(BookProgress p) {
    return _HistoryEntry(
      title: p.book.title,
      coverUrl: null,
      fallbackIcon: Icons.menu_book_rounded,
      subtitle: 'Chapter ${p.chapter + 1}',
      progress: null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(p.lastReadTimestamp),
      onTap: () async {
        final file = File(p.filePath);
        if (file.existsSync() && file.lengthSync() > 1000) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => openBookReaderFor(
                file: file,
                title: p.book.title,
                bookResult: p.book,
                initialChapter: p.chapter,
              ),
            ),
          );
          _loadHistory();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'File no longer available — redownload from Books.',
              ),
            ),
          );
        }
      },
      onDelete: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0F121C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete Book',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Delete "${p.book.title}" and its reading progress?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await BookProgressService.instance.delete(p.book.editionId);
          _loadHistory();
        }
      },
    );
  }

  _HistoryEntry _historyEntryFromManga(Map<String, dynamic> entry) {
    final manga = Manga.fromJson(entry['manga']);
    final chapterIndex = entry['chapterIndex'] as int;
    final pageIndex = entry['pageIndex'] as int;
    final chapters = (entry['chapters'] as List)
        .map((c) => MangaChapter.fromJson(c))
        .toList();
    final percent = chapters.isNotEmpty
        ? (chapterIndex + 1) / chapters.length
        : null;
    return _HistoryEntry(
      title: manga.title,
      coverUrl: manga.coverSmall.isNotEmpty ? manga.coverSmall : null,
      fallbackIcon: Icons.auto_stories_rounded,
      subtitle: chapters.isNotEmpty
          ? 'Chapter ${chapterIndex + 1} of ${chapters.length}'
          : 'Chapter ${chapterIndex + 1}',
      progress: percent,
      timestamp:
          DateTime.tryParse(entry['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MangaReaderPage(
                  manga: manga,
                  chapters: chapters,
                  currentChapterIndex: chapterIndex,
                  resumePageIndex: pageIndex,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        );
      },
      onDelete: () async {
        await _mangaService.removeHistory(manga.id);
        _loadHistory();
      },
    );
  }

  void _openManga(Manga manga) {
    Navigator.push(
      context,
      LiquidRevealRoute(
        page: MangaDetailsPage(manga: manga),
        tapPosition: null,
      ),
    ).then((_) => _loadLikedManga());
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingManga || _loadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
      );
    }

    return LibraryTabs(
      title: 'Library',
      titleIcon: Icons.collections_bookmark_rounded,
      tabs: [
        for (final section in LibrarySection.values)
          LibraryTab(
            label: section.label,
            icon: section.icon,
            builder: (_) => switch (section) {
              LibrarySection.saved => _buildSavedTab(),
              LibrarySection.inProgress => _buildInProgressTab(),
              LibrarySection.downloads => _buildDownloadsTab(),
            },
          ),
      ],
    );
  }

  List<_ReadLikedEntry> _likedEntries() {
    return [
      for (final b in BookLibraryService.instance.liked)
        _ReadLikedEntry(
          type: 'books',
          title: b.title,
          coverUrl: null, // libgen.li's list view carries no cover art.
          fallbackIcon: Icons.import_contacts_rounded,
          onTap: () => _openLikedBook(b),
        ),
      for (final m in _likedManga)
        _ReadLikedEntry(
          type: 'manga',
          title: m.title,
          coverUrl: m.coverSmall.isNotEmpty ? m.coverSmall : null,
          fallbackIcon: Icons.auto_stories_rounded,
          onTap: () => _openManga(m),
        ),
    ];
  }

  /// One grid across Books and Manga -- each its own persisted store
  /// (BookLibraryService, MangaService), merged only here for display.
  Widget _buildSavedTab() {
    final all = _likedEntries();
    if (all.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.favorite_rounded,
        title: 'Nothing liked yet',
        subtitle: 'Tap the heart on a book or manga to save it here.',
      );
    }
    final entries = _likedTypeFilter == 'all'
        ? all
        : all.where((e) => e.type == _likedTypeFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              _likedTypeChip('All', 'all'),
              const SizedBox(width: 6),
              _likedTypeChip('Books', 'books'),
              const SizedBox(width: 6),
              _likedTypeChip('Manga', 'manga'),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const LibraryEmptyState(
                  icon: Icons.favorite_rounded,
                  title: 'Nothing here',
                  subtitle: 'Nothing liked matches this filter yet.',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 300,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) =>
                      _ReadLikedEntryCard(entry: entries[index]),
                ),
        ),
      ],
    );
  }

  Widget _likedTypeChip(String label, String value) {
    final selected = _likedTypeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _likedTypeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C5CFF) : const Color(0xFF141824),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  /// Downloads here were audiobook chapters exclusively -- Books and Manga
  /// stream/read in place, no `DownloadTask`s of their own. Now that
  /// Audiobooks lives in Listen, its downloads tab moved there with it
  /// (see `music_page.dart`'s own Library); this one just stays honestly
  /// empty rather than carry a dead filter that can never match.
  Widget _buildDownloadsTab() {
    return const LibraryEmptyState(
      icon: Icons.download_done_rounded,
      title: 'No Downloads',
      subtitle:
          'Books and manga are read in place, not downloaded ahead '
          'of time.',
    );
  }

  /// Started but not finished. Same store as History, filtered on progress --
  /// there is only one reading log, and splitting it in the service would be
  /// a migration for a distinction the UI can make for free.
  Widget _buildInProgressTab() {
    final entries = _inProgressEntries;
    if (entries.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.play_circle_outline_rounded,
        title: 'Nothing in progress',
        subtitle:
            'Audiobooks, books and manga you are partway through wait '
            'for you here.',
      );
    }
    return _entryList(entries);
  }

  Widget _entryList(List<_HistoryEntry> entries) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return GestureDetector(
          onTap: entry.onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF12151E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: entry.coverUrl != null
                      ? Image.network(
                          entry.coverUrl!,
                          width: 50,
                          height: 75,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 50,
                            height: 75,
                            color: Colors.white10,
                            child: Icon(
                              entry.fallbackIcon,
                              color: Colors.white30,
                            ),
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 75,
                          color: Colors.white10,
                          child: Icon(
                            entry.fallbackIcon,
                            color: Colors.white30,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (entry.progress != null) ...[
                        LinearProgressIndicator(
                          value: entry.progress!.clamp(0.0, 1.0),
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF7C5CFF),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        entry.subtitle,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: entry.onDelete,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryEntry {
  final String title;
  final String? coverUrl;
  final IconData fallbackIcon;
  final String subtitle;
  final double? progress;
  final DateTime timestamp;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryEntry({
    required this.title,
    required this.coverUrl,
    required this.fallbackIcon,
    required this.subtitle,
    required this.progress,
    required this.timestamp,
    required this.onTap,
    required this.onDelete,
  });
}

/// A display-only merge of Books and Manga (two unrelated liked-item
/// models) so the Saved grid can render and filter them as one list.
/// Nothing is persisted through this type -- each source keeps its own
/// store (BookLibraryService, MangaService).
class _ReadLikedEntry {
  final String type; // 'books' | 'manga'
  final String title;
  final String? coverUrl;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  const _ReadLikedEntry({
    required this.type,
    required this.title,
    required this.coverUrl,
    required this.fallbackIcon,
    required this.onTap,
  });
}

class _ReadLikedEntryCard extends StatelessWidget {
  final _ReadLikedEntry entry;

  const _ReadLikedEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hasCover = entry.coverUrl != null && entry.coverUrl!.isNotEmpty;
    return GestureDetector(
      onTap: entry.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: hasCover
                  ? Image.network(
                      entry.coverUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF141824),
                        child: Icon(
                          entry.fallbackIcon,
                          color: Colors.white24,
                          size: 40,
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF141824),
                      child: Icon(
                        entry.fallbackIcon,
                        color: Colors.white24,
                        size: 40,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
