import 'package:flutter/material.dart';

import '../../widgets/common/sectioned_hub_scaffold.dart';
import '../../utils/hub_controller.dart';
import '../../utils/search_scope.dart';
import '../audiobooks/audiobooks_page.dart';
import '../manga/manga_page.dart';
import '../collection/books_library_page.dart';
import '../catalog/comics_page.dart';
import '../read/books_page.dart';

/// Read hub: Manga, Comics, Audiobooks, and the user's reading collection.
///
/// Sections are switched via the [SectionTopBar] chip bar. The active section
/// is driven by the shared [HubController] so navigation stays in sync.
class BooksHub extends StatelessWidget {
  const BooksHub({super.key});

  static Widget _buildSection(String activeSection) {
    switch (activeSection) {
      case 'manga':
        SearchScope.set('manga', label: 'Manga');
        return const MangaPage();
      case 'comics':
        SearchScope.set(null, label: 'Comics');
        return const ComicsPage();
      case 'books':
        SearchScope.set(null, label: 'Books');
        return const BooksPage();
      case 'audiobooks':
        SearchScope.set('audiobook', label: 'Audiobooks');
        return const AudiobooksPage();
      case 'collection':
        SearchScope.set(null, label: 'Library');
        return const BooksLibraryPage();
      default:
        SearchScope.set('audiobook', label: 'Audiobooks');
        return const AudiobooksPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionedHubScaffold(
      activeSectionOf: () => HubController.instance.booksSection,
      buildSection: _buildSection,
    );
  }
}
