import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../../../models/subtitle/subtitle_model.dart';
import '../subtitle_provider.dart';

class SubdlProvider extends SubtitleProvider {
  @override
  String get name => 'Subdl';

  final String _baseUrl = 'https://subdl.com';
  final String _apiBaseUrl = 'https://api3.subdl.com';

  @override
  Future<List<SubtitleVariant>> search(
    String movieName, {
    String? imdbId,
    int? season,
    int? episode,
  }) async {
    final List<SubtitleVariant> results = [];
    final bool isTvShow = season != null && episode != null;
    
    try {
      // 1. Search for the title
      final uri = Uri.parse('$_apiBaseUrl/auto?query=${Uri.encodeComponent(movieName)}');
      final response = await http.get(uri);
      
      if (response.statusCode != 200) return [];
      
      final data = jsonDecode(response.body);
      final List items = data['results'] ?? [];
      
      if (items.isEmpty) return [];

      // 2. Match the best result
      Map<String, dynamic>? bestMatch;
      for (final item in items) {
        final type = item['type']; // 'movie' or 'tv'
        final name = item['name'].toString().toLowerCase();
        
        if (isTvShow && type == 'tv' && name.contains(movieName.toLowerCase())) {
          bestMatch = item as Map<String, dynamic>;
          break;
        } else if (!isTvShow && type == 'movie' && name.contains(movieName.toLowerCase())) {
          bestMatch = item as Map<String, dynamic>;
          break;
        }
      }

      // Fallback to first if no exact type match
      bestMatch ??= items.first as Map<String, dynamic>;
      
      final link = bestMatch!['link'];
      if (link == null) return [];

      String targetUrl = '$_baseUrl$link';
      
      // 3. For TV Shows, find the correct season page
      if (isTvShow) {
        final showHtmlRes = await http.get(Uri.parse(targetUrl));
        if (showHtmlRes.statusCode == 200) {
          final doc = html_parser.parse(showHtmlRes.body);
          final links = doc.querySelectorAll('a');
          
          String? seasonLink;
          for (final a in links) {
            final text = a.text.trim().toLowerCase();
            if (text.contains('season $season')) {
              seasonLink = a.attributes['href'];
              break;
            }
          }
          
          if (seasonLink != null) {
            targetUrl = '$_baseUrl$seasonLink';
          }
        }
      }
      
      // 4. Scrape the final page (movie or season)
      final htmlRes = await http.get(Uri.parse(targetUrl));
      if (htmlRes.statusCode != 200) return [];
      
      final doc = html_parser.parse(htmlRes.body);
      
      final langDivs = doc.querySelectorAll('div[data-language-name]');
      for (final langDiv in langDivs) {
        final language = langDiv.attributes['data-language-name'] ?? 'Unknown';
        
        final rowLis = langDiv.querySelectorAll('li[data-row]');
        for (final rowLi in rowLis) {
          // If TV show, check episode
          if (isTvShow) {
            final epFrom = rowLi.attributes['data-episode-from'];
            
            bool match = false;
            if (epFrom != null && epFrom.isNotEmpty) {
              if (epFrom == episode.toString()) {
                match = true;
              }
            } else {
              // Fallback to regex on title
              final titleText = rowLi.querySelector('h4')?.text ?? '';
              final epRegex = RegExp('E0?$episode([^0-9]|\$)', caseSensitive: false);
              if (epRegex.hasMatch(titleText)) {
                match = true;
              }
            }
            if (!match) continue;
          }

          final aTag = rowLi.querySelector('a[href*="dl.subdl.com/subtitle/"]');
          final titleTag = rowLi.querySelector('h4');
          
          if (aTag != null && titleTag != null) {
            final dlLink = aTag.attributes['href'];
            final title = titleTag.text.trim();
            
            if (dlLink != null) {
              results.add(
                SubtitleVariant(
                  providerName: name,
                  language: language,
                  title: title,
                  downloadUrl: dlLink,
                  format: 'zip',
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('Subdl search error: $e');
    }

    return results;
  }

  @override
  Future<String?> download(SubtitleVariant variant) async {
    try {
      final res = await http.get(Uri.parse(variant.downloadUrl));
      if (res.statusCode != 200) return null;

      final archive = ZipDecoder().decodeBytes(res.bodyBytes);
      
      for (final file in archive) {
        if (file.isFile && (file.name.endsWith('.srt') || file.name.endsWith('.vtt'))) {
          final data = file.content as List<int>;
          
          final dir = await getTemporaryDirectory();
          final ext = file.name.endsWith('.vtt') ? 'vtt' : 'srt';
          final outPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.$ext';
          
          final outFile = File(outPath);
          await outFile.writeAsBytes(data);
          
          return outPath;
        }
      }
    } catch (e) {
      print('Subdl download error: $e');
    }
    return null;
  }
}
