import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/services/subtitles/subtitle_service.dart';

void main() {
  test('Subtitle search test - TV Show', () async {
    print('Searching subtitles for House of the Dragon S1E1...');
    final groups = await SubtitleService().fetchAllSubtitles(
      'House of the Dragon',
      imdbId: 'tt11198330', // IMDB ID for House of the Dragon
      season: 1,
      episode: 1,
    );
    if (groups.isEmpty) {
      print('No subtitles found.');
    } else {
      print('Found ' + groups.length.toString() + ' languages.');
      for (var g in groups) {
        print(g.language + ': ' + g.variants.length.toString() + ' variants');
        for (var v in g.variants.take(2)) {
          print('  - ' + v.providerName + ': ' + v.title);
        }
      }
    }
  });
}
