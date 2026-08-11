import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/my_list/my_list_item.dart';
import '../trakt/trakt_auth_service.dart';
import '../trakt/trakt_sync_service.dart';

abstract final class MyListService {
  static const _storageKey = 'my_list_v1';
  static const int maxItems = 500;

  static final ValueNotifier<List<MyListItem>> items = ValueNotifier<List<MyListItem>>([]);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored != null) {
      try {
        final list = (jsonDecode(stored) as List)
            .map((e) => MyListItem.fromJson(e as Map<String, dynamic>))
            .toList();
        items.value = list;
      } catch (_) {
        items.value = [];
      }
    }
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(items.value.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  static bool isInList(MyListItem item) {
    return items.value.any((i) => i.uniqueKey == item.uniqueKey);
  }

  static void add(MyListItem item) {
    if (isInList(item)) return;

    final newList = <MyListItem>[...items.value, item];
    newList.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    if (newList.length > maxItems) {
      newList.removeRange(maxItems, newList.length);
    }

    items.value = newList;
    _persist();

    // Push to Trakt if logged in (fire-and-forget, don't block UI)
    if (TraktAuthService().isLoggedIn.value) {
      TraktSyncService.syncUp(item);
    }
  }

  static void remove(MyListItem item) {
    items.value = items.value.where((i) => i.uniqueKey != item.uniqueKey).toList();
    _persist();
  }

  static void toggle(MyListItem item) {
    if (isInList(item)) {
      remove(item);
    } else {
      add(item);
    }
  }
}
