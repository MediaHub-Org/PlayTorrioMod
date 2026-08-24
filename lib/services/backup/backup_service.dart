import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exports/imports all of the app's local user data (library, likes,
/// playback history, settings, addon config, etc.) as a single JSON file.
///
/// Every service in the app persists to SharedPreferences, so this reads
/// and restores the entire key-value store generically instead of needing
/// a hand-written serializer per service. Kept as a flat key/value bundle
/// on purpose -- adding a cloud sync backend later is a matter of shipping
/// this same JSON envelope somewhere other than a local file, not a
/// rewrite of how the data is gathered.
abstract final class BackupService {
  static const _fileName = 'playtorrio_backup.json';

  static Future<File> _backupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Absolute path of the backup file (whether or not it exists yet), so
  /// the UI can show the user where their data lives.
  static Future<String> backupFilePath() async => (await _backupFile()).path;

  /// Writes every SharedPreferences key to the backup file and returns its
  /// path.
  static Future<String> export() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      for (final key in prefs.getKeys()) key: prefs.get(key),
    };
    final envelope = {
      'app': 'PlayTorrioV3',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    };
    final file = await _backupFile();
    await file.writeAsString(jsonEncode(envelope));
    return file.path;
  }

  /// Restores every key found in the backup file written by [export].
  /// Returns how many keys were restored. Existing keys not present in the
  /// backup are left untouched.
  static Future<int> import() async {
    final file = await _backupFile();
    if (!await file.exists()) {
      throw Exception('No backup file found at ${file.path}');
    }
    final envelope = jsonDecode(await file.readAsString());
    if (envelope is! Map || envelope['data'] is! Map) {
      throw const FormatException('Not a valid PlayTorrio backup file.');
    }
    final data = (envelope['data'] as Map).cast<String, dynamic>();
    final prefs = await SharedPreferences.getInstance();

    var restored = 0;
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is List) {
        await prefs.setStringList(
          entry.key,
          value.map((e) => e.toString()).toList(),
        );
      } else {
        continue;
      }
      restored++;
    }
    return restored;
  }
}
