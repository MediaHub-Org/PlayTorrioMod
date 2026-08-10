import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/audiobook/audiobook_model.dart';

class AudiobookBayScraper {
  static const String _baseUrl = 'https://audiobookbay.lu';

  static Future<List<Audiobook>> search(String query) async {
    try {
      // &tt=1 searches Title & Author, &sc=1 searches Description/Content
      final searchUrl = '$_baseUrl/?s=${Uri.encodeComponent(query)}&tt=1&sc=1';
      final res = await http.get(
        Uri.parse(searchUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      final RegExp postExp = RegExp(
        r'<div class="post[^"]*">([\s\S]*?)(?:<div class=\x27postMeta\x27>|<div class="postMeta">|</div>\s*</div>)',
        caseSensitive: false,
      );

      final matches = postExp.allMatches(res.body);
      final books = <Audiobook>[];

      for (final m in matches) {
        var block = m.group(1)!;

        // Support for Base64 encoded post elements (e.g., class="post re-ab")
        if (!block.contains('<a') && !block.contains('<img') && block.trim().length > 20) {
          try {
            final decoded = utf8.decode(
              base64.decode(block.trim().replaceAll(RegExp(r'\s+'), '')),
            );
            if (decoded.contains('<a')) {
              block = decoded;
            }
          } catch (_) {}
        }

        // Title and URL extraction
        final RegExp titleExp = RegExp(
          r'<a[^>]*href="(/abss/[^"]+)"[^>]*>([^<]+)</a>',
          caseSensitive: false,
        );
        final titleMatch = titleExp.firstMatch(block);
        if (titleMatch == null) continue;

        var url = titleMatch.group(1)!;
        if (url.startsWith('/')) url = '$_baseUrl$url';
        final title = titleMatch.group(2)!.trim();

        // Cover Poster extraction
        final RegExp imgExp = RegExp(
          r'<img[^>]*src="([^"]+)"',
          caseSensitive: false,
        );
        String coverImage = '';
        for (final imgM in imgExp.allMatches(block)) {
          final src = imgM.group(1)!;
          if (!src.contains('logo') &&
              !src.contains('search.gif') &&
              !src.contains('bz.jpg') &&
              !src.contains('tlt.gif') &&
              !src.contains('default_cover.jpg')) {
            coverImage = src.startsWith('/') ? '$_baseUrl$src' : src;
            break;
          }
        }

        books.add(
          Audiobook(
            uuid: 'abb_${url.hashCode}',
            audioBookId: url,
            dynamicSlugId: url,
            title: title,
            coverImage: coverImage,
            source: 'audiobookbay',
            pageUrl: url,
          ),
        );
      }
      return books;
    } catch (e) {
      debugPrint('AudiobookBay search error: $e');
      return [];
    }
  }

  static Future<List<AudiobookChapter>> getChapters(String url) async {
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      final RegExp hashExp = RegExp(
        r'Info Hash:</td>\s*<td[^>]*>\s*([a-fA-F0-9]{40})\s*</td>',
        caseSensitive: false,
      );
      final hashMatch = hashExp.firstMatch(res.body);
      if (hashMatch == null) return [];

      final infoHash = hashMatch.group(1)!;

      final RegExp trackerExp = RegExp(
        r'(?:Announce URL|Tracker):</td>\s*<td[^>]*>\s*([^<]+?)\s*</td>',
        caseSensitive: false,
      );

      final trackers = <String>{};
      for (final m in trackerExp.allMatches(res.body)) {
        final tr = m.group(1)!.trim();
        if (tr.startsWith('http') || tr.startsWith('udp')) {
          trackers.add(tr);
        }
      }

      // Generate base magnet URI
      final magnetUri = StringBuffer('magnet:?xt=urn:btih:$infoHash');
      for (final tr in trackers) {
        magnetUri.write('&tr=${Uri.encodeComponent(tr)}');
      }

      final magnetString = magnetUri.toString();

      // Robust file regex matching audio files
      final RegExp fileExp = RegExp(
        r'<td[^>]*>\s*([^<]+\.(?:mp3|m4b|m4a|aac|flac|ogg|opus|wav|wma))',
        caseSensitive: false,
      );

      final chapters = <AudiobookChapter>[];
      int fileIndex = 0;
      for (final m in fileExp.allMatches(res.body)) {
        final filename = m.group(1)!.trim();
        chapters.add(
          AudiobookChapter(
            title: filename,
            url: magnetString,
            isTorrent: true,
            torrentFileIndex: fileIndex,
          ),
        );
        fileIndex++;
      }

      if (chapters.isEmpty) {
        chapters.add(
          AudiobookChapter(
            title: 'Full Audiobook Torrent',
            url: magnetString,
            isTorrent: true,
            torrentFileIndex: 0,
          ),
        );
      }

      return chapters;
    } catch (e) {
      debugPrint('AudiobookBay getChapters error: $e');
      return [];
    }
  }
}
