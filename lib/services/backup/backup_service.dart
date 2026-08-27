import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_backup_settings.dart';

/// Exports/imports all of the app's local user data (library, likes,
/// playback history, settings, addon config, etc.) as a single JSON file --
/// locally, or to a WebDAV endpoint the user points at their own server
/// ([uploadToCloud]/[downloadFromCloud]).
///
/// Every service in the app persists to SharedPreferences, so this reads
/// and restores the entire key-value store generically instead of needing
/// a hand-written serializer per service. Kept as a flat key/value bundle
/// on purpose -- the local and cloud transports both ship the same
/// [_buildEnvelopeJson] envelope, just to a different destination.
abstract final class BackupService {
  static const _fileName = 'playtorrio_backup.json';

  static Future<File> _backupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Absolute path of the backup file (whether or not it exists yet), so
  /// the UI can show the user where their data lives.
  static Future<String> backupFilePath() async => (await _backupFile()).path;

  /// Builds the same versioned JSON envelope both the local file and the
  /// cloud transport write.
  static Future<String> _buildEnvelopeJson() async {
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
    return jsonEncode(envelope);
  }

  /// Restores every key found in an envelope produced by [_buildEnvelopeJson].
  /// Returns how many keys were restored. Existing keys not present in the
  /// backup are left untouched.
  static Future<int> _applyEnvelopeJson(String raw) async {
    final envelope = jsonDecode(raw);
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

  /// Writes every SharedPreferences key to the backup file and returns its
  /// path.
  static Future<String> export() async {
    final file = await _backupFile();
    await file.writeAsString(await _buildEnvelopeJson());
    return file.path;
  }

  /// Restores every key found in the backup file written by [export].
  static Future<int> import() async {
    final file = await _backupFile();
    if (!await file.exists()) {
      throw Exception('No backup file found at ${file.path}');
    }
    return _applyEnvelopeJson(await file.readAsString());
  }

  static Map<String, String> _webDavAuthHeader(CloudBackupConfig config) {
    final creds = base64Encode(utf8.encode('${config.username}:${config.password}'));
    return {'Authorization': 'Basic $creds'};
  }

  /// Uploads the same envelope [export] writes locally to a WebDAV endpoint
  /// via a plain HTTP PUT with Basic Auth -- no vendor lock-in, no
  /// request-signing dependency.
  static Future<void> uploadToCloud(CloudBackupConfig config) async {
    final uri = Uri.parse(config.url);
    final response = await http.put(
      uri,
      headers: {..._webDavAuthHeader(config), 'Content-Type': 'application/json'},
      body: await _buildEnvelopeJson(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('WebDAV upload failed (HTTP ${response.statusCode}).');
    }
  }

  /// Downloads and restores the envelope from a WebDAV endpoint.
  static Future<int> downloadFromCloud(CloudBackupConfig config) async {
    final uri = Uri.parse(config.url);
    final response = await http.get(uri, headers: _webDavAuthHeader(config));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('WebDAV download failed (HTTP ${response.statusCode}).');
    }
    return _applyEnvelopeJson(response.body);
  }
}
