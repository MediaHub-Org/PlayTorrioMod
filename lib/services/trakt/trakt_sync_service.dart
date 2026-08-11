import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/my_list/my_list_item.dart';
import '../../services/my_list/my_list_service.dart';
import 'trakt_api_service.dart';
import 'trakt_auth_service.dart';

class TraktSyncService {
  static DateTime? _lastSync;

  static Future<void> syncDown() async {
    final auth = TraktAuthService();
    if (!auth.isLoggedIn.value) return;

    // Check if anything changed since last sync
    final activities = await TraktApiService.getLastActivities();
    if (_lastSync != null && activities != null) {
      final watchlistUpdated = activities['watchlist']?['updated_at'];
      if (watchlistUpdated != null) {
        final updatedAt = DateTime.tryParse(watchlistUpdated.toString());
        if (updatedAt != null && updatedAt.isBefore(_lastSync!)) {
          return; // Nothing new
        }
      }
    }

    // Pull movie watchlist
    final movies = await TraktApiService.getWatchlistMovies();
    for (final raw in movies) {
      final item = MyListItem.fromTraktJson(raw);
      if (!MyListService.isInList(item)) {
        MyListService.add(item);
      }
    }

    // Pull show watchlist
    final shows = await TraktApiService.getWatchlistShows();
    for (final raw in shows) {
      final item = MyListItem.fromTraktJson(raw);
      if (!MyListService.isInList(item)) {
        MyListService.add(item);
      }
    }

    _lastSync = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_trakt_sync', _lastSync!.toIso8601String());
  }

  static Future<void> syncUp(MyListItem item) async {
    final auth = TraktAuthService();
    if (!auth.isLoggedIn.value) return;

    try {
      final ids = <String, dynamic>{};
      if (item.traktId != null) ids['trakt'] = item.traktId;
      if (item.imdbId != null) ids['imdb'] = item.imdbId;
      if (item.tmdbId != null) ids['tmdb'] = item.tmdbId;

      final Map<String, dynamic> entry = {'ids': ids};
      if (item.title.isNotEmpty) entry['title'] = item.title;
      if (item.year != null) entry['year'] = item.year;

      if (item.type == 'series') {
        await TraktApiService.addToWatchlist(movies: [], shows: [entry]);
      } else {
        await TraktApiService.addToWatchlist(movies: [entry], shows: []);
      }

      // Update local item to mark as synced
      final updated = item.copyWith(source: MyListSource.trakt);
      // Remove old, add updated to avoid duplicates
      MyListService.remove(item);
      MyListService.add(updated);
    } catch (e) {
      debugPrint('Trakt syncUp error: $e');
    }
  }

  static Future<bool> syncRemove(MyListItem item, BuildContext context) async {
    final auth = TraktAuthService();
    if (!auth.isLoggedIn.value || item.traktId == null) {
      MyListService.remove(item);
      return true;
    }

    // Ask user if they want to remove from Trakt too
    final removeFromTrakt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove from Trakt?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Also remove "${item.title}" from your Trakt watchlist?',
          style: TextStyle(color: Colors.white.withOpacity(0.55)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep on Trakt',
                style: TextStyle(color: Colors.white.withOpacity(0.45))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove from Trakt',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (removeFromTrakt == true) {
      try {
        final ids = <String, dynamic>{'trakt': item.traktId};
        final Map<String, dynamic> entry = {'ids': ids};
        if (item.type == 'series') {
          await TraktApiService.removeFromWatchlist(movies: [], shows: [entry]);
        } else {
          await TraktApiService.removeFromWatchlist(movies: [entry], shows: []);
        }
      } catch (e) {
        debugPrint('Trakt syncRemove error: $e');
      }
    }

    MyListService.remove(item);
    return true;
  }

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString('last_trakt_sync');
    if (lastSyncStr != null) {
      _lastSync = DateTime.tryParse(lastSyncStr);
    }
  }
}
