import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/services/subtitles/subtitle_service.dart';

void main() {
  test('Subtitle search test - How to Train Your Dragon (2025)', () async {
    final groups = await SubtitleService().fetchAllSubtitles(
      'How to Train Your Dragon',
      year: 2025,
    );
    expect(groups.isNotEmpty, true);
    // Verify that variant titles are for 2025, not 2010
    final allVariants = groups.expand((g) => g.variants).toList();
    expect(allVariants.isNotEmpty, true);
    final has2025 = allVariants.any((v) => v.title.contains('2025'));
    expect(has2025, true);
  });

  test('Subtitle search test - Life (1999)', () async {
    final groups = await SubtitleService().fetchAllSubtitles(
      'Life',
      year: 1999,
    );
    expect(groups.isNotEmpty, true);
    final allVariants = groups.expand((g) => g.variants).toList();
    expect(allVariants.isNotEmpty, true);
    // Verify that variant titles are for 1999, not 2017
    final has1999 = allVariants.any((v) => v.title.contains('1999'));
    expect(has1999, true);
  });

  test('Subtitle search test - TV Show', () async {
    final groups = await SubtitleService().fetchAllSubtitles(
      'House of the Dragon',
      imdbId: 'tt11198330',
      season: 1,
      episode: 1,
    );
    expect(groups.isNotEmpty, true);
  });
}
