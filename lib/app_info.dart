/// Single source of truth for how the app names itself to the user.
///
/// Every user-visible occurrence of the app's name should read from here --
/// the window/task-switcher title, the header wordmark, the splash screen,
/// Settings, and the updater. Before this existed the string was duplicated
/// across those files, so a rename meant hunting literals and missing some.
///
/// Deliberately NOT the place for two other things that merely look like the
/// app's name:
///
///  * **Stream source identifiers** -- `'PlayTorrio'` and `'PlayTorrioHTTP'`
///    are the built-in scrapers' `name`/`addonName`. They are compared against
///    in `StreamScraper` (to gate P2P) and in `ContinueWatchingService`, and
///    they are *persisted* inside saved continue-watching entries. Renaming
///    them would strand every saved resume point, so they stay literals.
///  * **Executable and bundle names** -- the Windows/Linux `BINARY_NAME` and
///    the macOS `PRODUCT_NAME` are build inputs baked into the installer and
///    packaging scripts, not display strings.
abstract final class AppInfo {
  /// The app's display name. Shown wherever the product names itself.
  static const String name = 'PlayTorrioMod';

  /// The subtitle under [name] on the splash screen.
  static const String tagline = 'Your Cinema Universe';
}
