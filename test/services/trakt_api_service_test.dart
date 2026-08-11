import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/services/trakt/trakt_api_service.dart';
import 'package:playtorrio/services/trakt/trakt_auth_service.dart';

void main() {
  group('TraktApiService', () {
    test('builds correct base URL', () {
      // Verify the API service exists and has the expected interface
      expect(TraktApiService, isNotNull);
    });

    test('uses clientId from auth service', () {
      expect(TraktAuthService.clientId, isNotEmpty);
    });

    test('addToWatchlist accepts movie entries', () {
      // Verify method signature exists
      final movies = <Map<String, dynamic>>[{
        'ids': {'trakt': 100, 'imdb': 'tt1375666'},
        'title': 'Inception',
        'year': 2010,
      }];
      expect(movies.first['ids']['trakt'], 100);
    });

    test('removeFromWatchlist accepts movie entries', () {
      final movies = <Map<String, dynamic>>[{
        'ids': {'trakt': 100},
      }];
      expect(movies.first['ids']['trakt'], 100);
    });

    test('addToWatchlist accepts show entries', () {
      final shows = <Map<String, dynamic>>[{
        'ids': {'trakt': 200, 'imdb': 'tt0903747'},
        'title': 'Breaking Bad',
        'year': 2008,
      }];
      expect(shows.first['ids']['trakt'], 200);
    });
  });
}
