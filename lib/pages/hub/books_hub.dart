import 'package:flutter/material.dart';

import '../../widgets/common/sectioned_hub_scaffold.dart';
import '../../utils/hub_controller.dart';
import '../../utils/search_scope.dart';
import '../manga/manga_page.dart';
import '../collection/books_library_page.dart';
import '../catalog/comics_page.dart';
import '../read/books_page.dart';

/// Read hub: Books, Comics, Manga, and the user's library.
///
/// Comics and Manga used to share one section with a sub-tab, the same way
/// Movies/Series does in Watch -- now independent top-level sections, since
/// Audiobooks moving to Listen (paired with Podcasts there instead, both
/// being episodic spoken audio) freed the fourth slot.
///
/// Sections are switched via the [SectionTopBar] — chips on tablet/desktop,
/// a dropdown on mobile. The active section is driven by the shared
/// [HubController] so navigation stays in sync.
class BooksHub extends StatelessWidget {
  const BooksHub({super.key});

  static Widget _buildSection(String activeSection) {
    switch (activeSection) {
      case 'comics':
        SearchScope.set(null, label: 'Comics');
        return const ComicsPage();
      case 'manga':
        SearchScope.set('manga', label: 'Manga');
        return const MangaPage();
      case 'collection':
        SearchScope.set(null, label: 'Library');
        return const BooksLibraryPage();
      case 'books':
      default:
        SearchScope.set(null, label: 'Books');
        return const BooksPage();
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
