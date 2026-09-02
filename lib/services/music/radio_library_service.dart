import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'radio_browser_service.dart';

/// Persists the user's liked radio stations so they can show up in Listen's
/// Library. Mirrors [PodcastLibraryService]'s shape.
class RadioLibraryService extends ChangeNotifier {
  static final RadioLibraryService instance = RadioLibraryService._internal();
  RadioLibraryService._internal();

  static const String _likedKey = 'radio_liked_v1';

  List<RadioStation> _liked = [];
  bool _initialized = false;

  List<RadioStation> get liked => _liked;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_likedKey);
      if (json != null) {
        final list = jsonDecode(json) as List<dynamic>;
        _liked = list
            .whereType<Map<String, dynamic>>()
            .map(RadioStation.fromLocalJson)
            .toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('RadioLibraryService init error: $e');
    }
  }

  bool isLiked(String id) => _liked.any((s) => s.id == id);

  Future<void> toggleLike(RadioStation station) async {
    final idx = _liked.indexWhere((s) => s.id == station.id);
    if (idx >= 0) {
      _liked.removeAt(idx);
    } else {
      _liked.insert(0, station);
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_liked.map((s) => s.toJson()).toList());
    await prefs.setString(_likedKey, json);
  }
}
