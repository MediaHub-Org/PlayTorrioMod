import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorrio/services/trakt/trakt_auth_service.dart';

void main() {
  group('TraktAuthService', () {
    late TraktAuthService auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      auth = TraktAuthService();
      await auth.initialize();
    });

    test('starts logged out', () {
      expect(auth.isLoggedIn.value, false);
    });

    test('isLoading starts false', () {
      expect(auth.isLoading.value, false);
    });

    test('accessToken is null when logged out', () {
      expect(auth.accessToken, isNull);
    });

    test('has clientId constant', () {
      expect(TraktAuthService.clientId, isNotEmpty);
    });

    test('has redirectUri constant', () {
      expect(TraktAuthService.redirectUri, 'playtorrio://trakt-callback');
    });

    test('logout clears state when already logged out', () async {
      await auth.logout();
      expect(auth.isLoggedIn.value, false);
    });

    test('handleCallback with no code returns false', () async {
      final result = await auth.handleCallback(Uri.parse('playtorrio://trakt-callback?error=denied'));
      expect(result, false);
    });

    test('ValueNotifier is reactive', () {
      int notifyCount = 0;
      auth.isLoggedIn.addListener(() => notifyCount++);

      // simulate login
      auth.isLoggedIn.value = true;
      expect(notifyCount, 1);

      auth.isLoggedIn.value = true; // same value, should not notify
      expect(notifyCount, 1);

      auth.isLoggedIn.value = false;
      expect(notifyCount, 2);
    });
  });
}
