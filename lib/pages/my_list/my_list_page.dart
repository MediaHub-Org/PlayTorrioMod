import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/my_list/my_list_item.dart';
import '../../services/my_list/my_list_service.dart';
import '../../utils/route_transitions.dart';
import '../details/details_page.dart';
import '../../models/movie/movie.dart';

class MyListPage extends StatefulWidget {
  const MyListPage({super.key});

  @override
  State<MyListPage> createState() => _MyListPageState();
}

class _MyListPageState extends State<MyListPage> {
  String _sortBy = 'recent'; // 'recent', 'title', 'year'

  List<MyListItem> _getSortedItems() {
    final list = List<MyListItem>.from(MyListService.items.value);
    switch (_sortBy) {
      case 'recent':
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case 'title':
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'year':
        list.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
        break;
    }
    return list;
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    return 5;
  }

  void _navigateToDetail(MyListItem item) {
    final movie = Movie(
      id: item.traktId?.toString() ?? item.tmdbId?.toString() ?? item.imdbId ?? '',
      name: item.title,
      poster: item.poster,
      year: item.year?.toString(),
      type: item.type,
      addonBaseUrl: '',
    );

    Navigator.push(
      context,
      LiquidRevealRoute(
        page: DetailsPage(movie: movie),
        tapPosition: null,
      ),
    );
  }

  Future<void> _confirmRemove(MyListItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove from My List?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Remove "${item.title}" from your list?',
          style: TextStyle(color: Colors.white.withOpacity(0.55)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.45))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      MyListService.remove(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${item.title}"'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'My List',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButton<String>(
              value: _sortBy,
              underline: const SizedBox.shrink(),
              dropdownColor: const Color(0xFF151822),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: const [
                DropdownMenuItem(value: 'recent', child: Text('Recently Added')),
                DropdownMenuItem(value: 'title', child: Text('Alphabetical')),
                DropdownMenuItem(value: 'year', child: Text('By Year')),
              ],
              onChanged: (v) => setState(() => _sortBy = v!),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<MyListItem>>(
        valueListenable: MyListService.items,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border_rounded,
                      size: 64, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text(
                    'Your list is empty',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse movies to add them here',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.45), fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final sorted = _getSortedItems();
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _getCrossAxisCount(context),
                childAspectRatio: 2 / 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final item = sorted[index];
                return GestureDetector(
                  onTap: () => _navigateToDetail(item),
                  onLongPress: () => _confirmRemove(item),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: item.poster != null
                              ? CachedNetworkImage(
                                  imageUrl: item.poster!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: const Color(0xFF15171F),
                                    child: const Icon(Icons.movie_rounded,
                                        color: Colors.white24, size: 32),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFF15171F),
                                  child: const Icon(Icons.movie_rounded,
                                      color: Colors.white24, size: 32),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.year != null)
                        Text(
                          '${item.year}',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.45)),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
