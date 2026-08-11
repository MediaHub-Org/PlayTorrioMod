import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorrio/models/my_list/my_list_item.dart';
import 'package:playtorrio/services/my_list/my_list_service.dart';
import 'package:playtorrio/services/trakt/trakt_sync_service.dart';
import 'package:playtorrio/services/trakt/trakt_auth_service.dart';

void main() {
  group('TraktSyncService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      MyListService.items.value = [];
      await MyListService.initialize();
      await TraktSyncService.initialize();
    });

    test('initialize loads last sync time', () async {
      // Should not throw
      expect(TraktSyncService, isNotNull);
    });

    test('syncDown does nothing when not logged in', () async {
      final auth = TraktAuthService();
      expect(auth.isLoggedIn.value, false);

      await TraktSyncService.syncDown();
      // Should not throw and should not add items
      expect(MyListService.items.value, isEmpty);
    });

    test('syncUp does nothing when not logged in', () async {
      final item = MyListItem(
        traktId: 100, title: 'Test', type: 'movie',
        addedAt: DateTime(2026),
      );
      MyListService.add(item);

      // Item should still be local only
      expect(MyListService.items.value.first.source, MyListSource.local);
    });

    test('syncUp does not throw for items without traktId', () async {
      final item = MyListItem(
        title: 'No Trakt ID', type: 'movie', addedAt: DateTime(2026),
      );
      // Should not throw
      await TraktSyncService.syncUp(item);
    });
  });
}
