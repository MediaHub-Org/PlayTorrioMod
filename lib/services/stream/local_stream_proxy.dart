import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Lightweight embedded Loopback HTTP/HLS proxy server running on 127.0.0.1.
///
/// Handles upstream video requests requiring specific Referer, Origin, or User-Agent
/// headers. For M3U8 playlists, rewrites nested segment and variant URLs so that
/// the media demuxer / video player always fetches with valid headers without getting HTTP 403/429.
class LocalStreamProxy {
  static final LocalStreamProxy instance = LocalStreamProxy._internal();
  LocalStreamProxy._internal();

  HttpServer? _server;
  int? _port;
  final HttpClient _httpClient = HttpClient()
    ..badCertificateCallback = ((cert, host, port) => true)
    ..connectionTimeout = const Duration(seconds: 10);

  bool get isRunning => _server != null;
  int get port => _port ?? 0;

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      debugPrint('[LocalStreamProxy] Started loopback proxy server on port $_port');
      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('[LocalStreamProxy] Server error: $e');
      });
    } catch (e) {
      debugPrint('[LocalStreamProxy] Failed to start server: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }

  /// Automatically derives required Origin and Referer headers based on known video CDNs.
  static Map<String, String> resolveHeadersForUrl(String url, [Map<String, String>? initialHeaders]) {
    final h = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    };
    if (initialHeaders != null) {
      h.addAll(initialHeaders);
    }

    final lower = url.toLowerCase();
    if (lower.contains('peakstorm.top') ||
        lower.contains('majorplay.net') ||
        lower.contains('slast430did.com') ||
        lower.contains('vidzy.cc') ||
        lower.contains('vimeos.zip') ||
        lower.contains('wecollege.net')) {
      h['Referer'] = 'https://www.movy.bz/';
      h['Origin'] = 'https://www.movy.bz';
    } else if (lower.contains('chillflix.lol')) {
      h['Referer'] = 'https://www.chillflix.lol/';
      h['Origin'] = 'https://www.chillflix.lol';
    } else if (lower.contains('hclod.qzz.io') || lower.contains('watchplay.shop')) {
      h['Referer'] = 'https://v1.watchplay.shop/';
      h['Origin'] = 'https://v1.watchplay.shop';
    } else if (lower.contains('valhallastream') || lower.contains('1shows.app') || lower.contains('rivestream')) {
      h['Referer'] = 'https://www.rivestream.app/';
      h['Origin'] = 'https://www.rivestream.app';
    } else if (lower.contains('videasy') || lower.contains('speedracelight')) {
      h['Referer'] = 'https://player.videasy.to/';
      h['Origin'] = 'https://player.videasy.to';
    } else if (lower.contains('streamraiwind.stream') || lower.contains('vuflix.co')) {
      h['Referer'] = 'https://vuflix.co/';
      h['Origin'] = 'https://vuflix.co';
    } else if (lower.contains('net77.cc') || lower.contains('nm-cdn4.top')) {
      h['Referer'] = 'https://net77.cc/';
      h['Origin'] = 'https://net77.cc';
    } else if (lower.contains('gn1r5n.org') || lower.contains('owphbf24.com')) {
      h['Referer'] = 'https://gn1r5n.org/';
      h['Origin'] = 'https://gn1r5n.org';
    }

    return h;
  }

  /// Wraps a given target URL with the local proxy URL matching player demuxer expectations.
  String getProxiedUrl(String targetUrl, Map<String, String>? headers) {
    if (_port == null || targetUrl.isEmpty) return targetUrl;
    if (targetUrl.startsWith('http://127.0.0.1') || targetUrl.startsWith('http://localhost')) {
      return targetUrl;
    }

    final resolvedHeaders = resolveHeadersForUrl(targetUrl, headers);
    final lower = targetUrl.toLowerCase();
    final String extPath;
    if (lower.contains('.mp4')) {
      extPath = '/proxy.mp4';
    } else if (lower.contains('.ts')) {
      extPath = '/proxy.ts';
    } else {
      extPath = '/proxy.m3u8';
    }

    final headersJson = jsonEncode(resolvedHeaders);
    final encodedTarget = Uri.encodeComponent(targetUrl);
    final encodedHeaders = Uri.encodeComponent(headersJson);
    return 'http://127.0.0.1:$_port$extPath?url=$encodedTarget&headers=$encodedHeaders';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!request.uri.path.startsWith('/proxy')) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found')
        ..close();
      return;
    }

    final targetUrl = request.uri.queryParameters['url'];
    final rawHeaders = request.uri.queryParameters['headers'];

    if (targetUrl == null || targetUrl.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('Missing url parameter')
        ..close();
      return;
    }

    Map<String, String> parsedHeaders = {};
    if (rawHeaders != null && rawHeaders.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawHeaders) as Map<String, dynamic>;
        parsedHeaders = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      } catch (_) {}
    }

    final effectiveHeaders = resolveHeadersForUrl(targetUrl, parsedHeaders);

    try {
      final upstreamUri = Uri.parse(targetUrl);
      final clientReq = await _httpClient.getUrl(upstreamUri);

      // Forward custom headers
      effectiveHeaders.forEach((k, v) {
        if (v.isNotEmpty) {
          clientReq.headers.set(k, v);
        }
      });

      // Forward Range request if present (for seeking in MP4/TS)
      final clientRange = request.headers.value(HttpHeaders.rangeHeader);
      if (clientRange != null) {
        clientReq.headers.set(HttpHeaders.rangeHeader, clientRange);
      }

      final upstreamRes = await clientReq.close();
      final bodyBytes = await upstreamRes.fold<List<int>>([], (prev, element) => prev..addAll(element));

      // Inspect binary header bytes to verify if it is an actual M3U8 text playlist
      final isM3u8 = bodyBytes.length >= 7 &&
          utf8.decode(bodyBytes.sublist(0, 7), allowMalformed: true).startsWith('#EXTM3U');

      if (isM3u8) {
        // Read the M3U8 playlist and rewrite nested URLs to route through proxy
        final bodyText = utf8.decode(bodyBytes, allowMalformed: true);
        final lines = bodyText.split('\n');

        final headersJsonStr = jsonEncode(effectiveHeaders);
        final encodedHeadersStr = Uri.encodeComponent(headersJsonStr);

        final rewrittenLines = lines.map((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return line;

          if (trimmed.startsWith('#')) {
            // Handle #EXT-X-MAP:URI="...", #EXT-X-KEY:URI="...", #EXT-X-MEDIA:URI="..."
            if (trimmed.contains('URI="')) {
              final uriRegex = RegExp(r'URI="([^"]+)"');
              return trimmed.replaceAllMapped(uriRegex, (match) {
                final matchedUri = match.group(1)!;
                var resolvedUri = upstreamUri.resolve(matchedUri);
                if (upstreamUri.hasQuery && !resolvedUri.hasQuery) {
                  resolvedUri = resolvedUri.replace(query: upstreamUri.query);
                }
                final proxiedUri =
                    'http://127.0.0.1:$_port/proxy.m3u8?url=${Uri.encodeComponent(resolvedUri.toString())}&headers=$encodedHeadersStr';
                return 'URI="$proxiedUri"';
              });
            }
            return line;
          }

          // Relative or absolute segment / variant stream URL
          var resolvedUri = upstreamUri.resolve(trimmed);
          if (upstreamUri.hasQuery && !resolvedUri.hasQuery) {
            resolvedUri = resolvedUri.replace(query: upstreamUri.query);
          }
          return 'http://127.0.0.1:$_port/proxy.m3u8?url=${Uri.encodeComponent(resolvedUri.toString())}&headers=$encodedHeadersStr';
        });

        final rewrittenBody = rewrittenLines.join('\n');
        final outputBytes = utf8.encode(rewrittenBody);

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
          ..headers.set(HttpHeaders.accessControlAllowOriginHeader, '*')
          ..headers.set(HttpHeaders.contentLengthHeader, outputBytes.length)
          ..add(outputBytes);
        await request.response.close();
      } else {
        // Direct binary video stream / TS chunks / MP4 / disguised JPG chunks
        request.response
          ..statusCode = upstreamRes.statusCode
          ..headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');

        final upstreamContentType = upstreamRes.headers.contentType?.toString().toLowerCase() ?? '';
        final String effectiveContentType;
        if (bodyBytes.isNotEmpty && bodyBytes[0] == 0x47) {
          // MPEG-TS sync byte 0x47 -> pure TS video segment
          effectiveContentType = 'video/MP2T';
        } else if (bodyBytes.length >= 8 &&
            (bodyBytes[4] == 0x66 && bodyBytes[5] == 0x74 && bodyBytes[6] == 0x79 && bodyBytes[7] == 0x70)) {
          // "ftyp" magic header -> MP4 / M4S / FMP4
          effectiveContentType = 'video/mp4';
        } else if (upstreamContentType.contains('text/html') ||
            upstreamContentType.contains('text/plain') ||
            upstreamContentType.isEmpty) {
          effectiveContentType = 'video/MP2T';
        } else {
          effectiveContentType = upstreamContentType;
        }

        request.response.headers.set(HttpHeaders.contentTypeHeader, effectiveContentType);
        request.response.headers.set(HttpHeaders.contentLengthHeader, bodyBytes.length);

        final contentRange = upstreamRes.headers.value(HttpHeaders.contentRangeHeader);
        if (contentRange != null) {
          request.response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
        }
        final acceptRanges = upstreamRes.headers.value(HttpHeaders.acceptRangesHeader);
        if (acceptRanges != null) {
          request.response.headers.set(HttpHeaders.acceptRangesHeader, acceptRanges);
        }

        request.response.add(bodyBytes);
        await request.response.close();
      }
    } catch (e) {
      if (!request.response.headers.chunkedTransferEncoding) {
        request.response
          ..statusCode = HttpStatus.badGateway
          ..write('Proxy upstream failure: $e');
      }
      await request.response.close().catchError((_) {});
    }
  }
}
