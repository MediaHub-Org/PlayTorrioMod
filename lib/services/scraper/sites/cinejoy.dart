import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'package:wasm_run/wasm_run.dart';
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';
import 'tmdb_helper.dart';

/// Cinejoy Stream Scraper for PlayTorrioHTTP.
///
/// Encrypts media requests using Cinejoy's self-contained WebAssembly module
/// (crush.wasm) and decrypts the resulting AES-256-GCM payloads in pure Dart.
///
/// Extracts 4K & HD HLS playlists, direct MP4 streams, and subtitles from
/// all active servers (Lisbon, Solara, Athens, Castle, Canaias).
class CinejoyScraper extends StreamScraper {
  @override
  String get name => 'PlayTorrioHTTP';

  static const _apiBase = 'https://api.shegu.st';
  static const _origin = 'https://cinejoy.to';
  static const _referer = 'https://cinejoy.to/';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const _defaultHeaders = {
    'User-Agent': _ua,
    'Origin': _origin,
    'Referer': _referer,
    'Accept': 'application/json, text/plain, */*',
  };

  static const List<Map<String, dynamic>> _fallbackServers = [
    {'name': 'Lisbon', '4k': true, 'status': 'ok'},
    {'name': 'Solara', '4k': false, 'status': 'ok'},
    {'name': 'Athens', '4k': false, 'status': 'ok'},
    {'name': 'Castle', '4k': false, 'status': 'ok'},
    {'name': 'Canaias', '4k': false, 'status': 'ok'},
  ];

  static WasmModule? _cachedModule;
  static Uint8List? _cachedWasmBytes;

  static Future<WasmModule?> _getWasmModule() async {
    if (_cachedModule != null) return _cachedModule;

    try {
      await WasmRunLibrary.setUp();

      if (_cachedWasmBytes == null) {
        try {
          final byteData = await rootBundle.load('assets/wasm/crush.wasm');
          _cachedWasmBytes = byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          );
        } catch (_) {
          final res = await http.get(
            Uri.parse('$_apiBase/crush.wasm'),
            headers: _defaultHeaders,
          ).timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            _cachedWasmBytes = res.bodyBytes;
          }
        }
      }

      if (_cachedWasmBytes != null) {
        _cachedModule = await compileWasmModule(_cachedWasmBytes!);
        debugPrint('[CinejoyScraper] WASM module compiled successfully (${_cachedWasmBytes!.length} bytes)');
      }
    } catch (e, stack) {
      debugPrint('[CinejoyScraper] Failed to compile WASM module: $e\n$stack');
    }
    return _cachedModule;
  }

  @override
  Stream<StreamSource> scrapeStream({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) {
    final controller = StreamController<StreamSource>();
    final isTv = (type == 'series' || type == 'tv');
    final mediaType = isTv ? 'tv' : 'movie';

    () async {
      try {
        final tmdbId = await TmdbHelper.resolveTmdbId(
          imdbId: imdbId,
          title: title,
          type: mediaType,
          year: year,
        );

        if (tmdbId == null || tmdbId <= 0) {
          debugPrint('[CinejoyScraper] Could not resolve TMDb ID for "$title"');
          controller.close();
          return;
        }

        debugPrint(
            '[CinejoyScraper] Starting scrape for "$title" (tmdb: $tmdbId, S:${season}E:$episode)');

        final wasmMod = await _getWasmModule();
        if (wasmMod == null) {
          debugPrint('[CinejoyScraper] WASM engine not available');
          controller.close();
          return;
        }

        // 1. Fetch available servers dynamically
        List<Map<String, dynamic>> servers = _fallbackServers;
        try {
          final srvRes = await http
              .get(Uri.parse('$_apiBase/servers'), headers: _defaultHeaders)
              .timeout(const Duration(seconds: 4));
          if (srvRes.statusCode == 200) {
            final data = jsonDecode(srvRes.body);
            if (data is Map && data['servers'] is List) {
              servers = (data['servers'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            }
          }
        } catch (_) {
          // Use fallback servers
        }

        final seenUrls = <String>{};

        // 2. Query all active servers concurrently
        final serverTasks = servers.map((srv) async {
          final srvName = srv['name']?.toString() ?? '';
          if (srvName.isEmpty || srv['status'] == 'disabled') return;
          // Sakura is anime-only, skip non-anime unless appropriate
          if (srvName.toLowerCase() == 'sakura' && !isTv) return;

          try {
            final payload = <String, String>{'tmdb': tmdbId.toString()};
            final String targetPath;
            if (isTv) {
              payload['season'] = (season ?? 1).toString();
              payload['episode'] = (episode ?? 1).toString();
              targetPath = '/$srvName/series';
            } else {
              targetPath = '/$srvName/movie';
            }

            debugPrint('[CinejoyScraper] Querying $targetPath with payload $payload');
            final result = await _executeEncryptedQuery(
              wasmModule: wasmMod,
              path: targetPath,
              payload: payload,
            );

            final dynamic streamData = result != null
                ? (result['data'] is Map ? result['data']['stream'] : result['stream'])
                : null;
            final streams = (streamData is List) ? streamData : const [];

            debugPrint('[CinejoyScraper] [$srvName] Result: Got ${streams.length} stream(s)');

            if (streams.isEmpty) return;

            final is4k = srv['4k'] == true;

            for (final st in streams) {
              if (st is! Map) continue;
              final stType = st['type']?.toString();

              if (stType == 'hls') {
                final playlistUrl = (st['playlist'] ?? '').toString().trim();
                if (playlistUrl.isEmpty || seenUrls.contains(playlistUrl)) {
                  continue;
                }
                seenUrls.add(playlistUrl);

                final quality = is4k ? '4K / 1080p' : 'Auto';
                final streamTitle = '[Cinejoy - $srvName] $quality';
                final desc = '$srvName • $quality • HLS';

                debugPrint('[CinejoyScraper SUCCESS] Added stream source from $srvName: $playlistUrl');

                if (!controller.isClosed) {
                  controller.add(
                    _buildSource(
                      url: playlistUrl,
                      title: streamTitle,
                      quality: quality,
                      description: desc,
                    ),
                  );
                }
              } else if (stType == 'file' && st['qualities'] is Map) {
                final quals = st['qualities'] as Map;
                final subId = st['id']?.toString();

                for (final entry in quals.entries) {
                  final qKey = entry.key.toString();
                  final qVal = entry.value;
                  if (qVal is! Map) continue;

                  final fileUrl = (qVal['url'] ?? '').toString().trim();
                  if (fileUrl.isEmpty || !fileUrl.startsWith('http') || seenUrls.contains(fileUrl)) {
                    continue;
                  }
                  seenUrls.add(fileUrl);

                  final quality = qKey.endsWith('p') || qKey.toLowerCase() == '4k' ? qKey : '${qKey}p';
                  final label = subId != null && subId.isNotEmpty ? '$srvName ($subId)' : srvName;
                  final streamTitle = '[Cinejoy - $label] $quality';
                  final format = (qVal['type'] ?? 'mp4').toString().toUpperCase();
                  final desc = '$label • $quality • $format';

                  debugPrint('[CinejoyScraper SUCCESS] Added MP4 source from $label: $fileUrl');

                  if (!controller.isClosed) {
                    controller.add(
                      _buildSource(
                        url: fileUrl,
                        title: streamTitle,
                        quality: quality,
                        description: desc,
                      ),
                    );
                  }
                }
              }
            }
          } catch (e, stack) {
            debugPrint('[CinejoyScraper] Error querying server $srvName: $e\n$stack');
          }
        });

        await Future.wait(serverTasks);
      } catch (e, stack) {
        debugPrint('[CinejoyScraper] Top-level error: $e\n$stack');
      } finally {
        if (!controller.isClosed) {
          controller.close();
        }
      }
    }();

    return controller.stream;
  }

  /// Encrypts the payload via WASM, dispatches POST /g, and decrypts the response.
  static Future<Map<String, dynamic>?> _executeEncryptedQuery({
    required WasmModule wasmModule,
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final instance = await wasmModule.builder().build();
      final alloc = instance.getFunction('alloc')!;
      final sealRequest = instance.getFunction('seal_request')!;
      final memory = instance.getMemory('memory')!;

      final reqJson = jsonEncode({'path': path, 'payload': payload});
      final reqBytes = Uint8List.fromList(utf8.encode(reqJson));

      final rnd = Random.secure();
      final randBytes = Uint8List.fromList(List.generate(44, (_) => rnd.nextInt(256)));

      final outCap = reqBytes.length + 512;

      final reqPtr = _unwrapInt(alloc([reqBytes.length]));
      final randPtr = _unwrapInt(alloc([randBytes.length]));
      final outPtr = _unwrapInt(alloc([outCap]));

      memory.view.setRange(reqPtr, reqPtr + reqBytes.length, reqBytes);
      memory.view.setRange(randPtr, randPtr + randBytes.length, randBytes);

      final outLen = _unwrapInt(sealRequest([
        reqPtr,
        reqBytes.length,
        randPtr,
        randBytes.length,
        outPtr,
        outCap,
      ]));

      if (outLen <= 98) {
        debugPrint('[CinejoyScraper] seal_request outLen too small: $outLen');
        return null;
      }

      final outBytes = Uint8List.fromList(memory.view.sublist(outPtr, outPtr + outLen));

      final dealloc = instance.getFunction('dealloc');
      if (dealloc != null) {
        try {
          dealloc([reqPtr, reqBytes.length]);
          dealloc([randPtr, randBytes.length]);
          dealloc([outPtr, outCap]);
        } catch (_) {}
      }

      final responseKey = outBytes.sublist(0, 32);
      final keyId = outBytes[32];
      final ephemeralPublic = outBytes.sublist(33, 98);
      final body = outBytes.sublist(98);

      final client = http.Client();
      final postRes = await client.post(
        Uri.parse('$_apiBase/g'),
        headers: {
          'User-Agent': _ua,
          'Origin': _origin,
          'Referer': '$_origin/watch',
          'Content-Type': 'application/octet-stream',
        },
        body: body,
      ).timeout(const Duration(seconds: 7));
      client.close();

      if (postRes.statusCode != 200 || postRes.bodyBytes.length < 28) {
        debugPrint('[CinejoyScraper] POST /g status: ${postRes.statusCode}, bodyLen: ${postRes.bodyBytes.length}');
        return null;
      }

      final respBytes = postRes.bodyBytes;
      final iv = respBytes.sublist(0, 12);
      final ciphertext = respBytes.sublist(12);

      final prefixBytes = utf8.encode('lumen-gate-v2');
      final aad = Uint8List(prefixBytes.length + 3 + ephemeralPublic.length);
      aad.setRange(0, prefixBytes.length, prefixBytes);
      aad[prefixBytes.length] = 0;
      aad[prefixBytes.length + 1] = 2;
      aad[prefixBytes.length + 2] = keyId;
      aad.setRange(prefixBytes.length + 3, aad.length, ephemeralPublic);

      final decryptedBytes = _aesGcmDecrypt(
        key: responseKey,
        iv: iv,
        ciphertext: ciphertext,
        aad: aad,
      );

      final decryptedJson = utf8.decode(decryptedBytes);
      final decoded = jsonDecode(decryptedJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e, stack) {
      debugPrint('[CinejoyScraper] _executeEncryptedQuery error: $e\n$stack');
    }
    return null;
  }

  static int _unwrapInt(dynamic val) {
    if (val is List && val.isNotEmpty) {
      return (val.first as num).toInt();
    }
    return (val as num).toInt();
  }

  static Uint8List _aesGcmDecrypt({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List ciphertext,
    required Uint8List aad,
  }) {
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      128,
      iv,
      aad,
    );
    cipher.init(false, params);
    return cipher.process(ciphertext);
  }

  StreamSource _buildSource({
    required String url,
    required String title,
    required String quality,
    required String description,
  }) {
    return StreamSource(
      name: title,
      title: title,
      description: description,
      url: url,
      addonName: 'PlayTorrioHTTP',
      headers: {
        'User-Agent': _ua,
        'Referer': _referer,
        'Origin': _origin,
      },
      behaviorHints: {
        'notWebReady': false,
        'proxyHeaders': {
          'request': {
            'User-Agent': _ua,
            'Referer': _referer,
            'Origin': _origin,
          },
        },
      },
    );
  }
}
