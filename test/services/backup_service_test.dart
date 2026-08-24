import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorrio/services/backup/backup_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempDir);
  final Directory tempDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('playtorrio_backup_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    SharedPreferences.setMockInitialValues({
      'a_string': 'hello',
      'a_bool': true,
      'an_int': 42,
      'a_double': 3.14,
      'a_list': ['x', 'y', 'z'],
    });
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('export writes a JSON file and import round-trips every value type', () async {
    final path = await BackupService.export();
    expect(File(path).existsSync(), isTrue);

    // Simulate a fresh install / different device: clear prefs, then import.
    SharedPreferences.setMockInitialValues({});
    final restored = await BackupService.import();
    expect(restored, 5);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('a_string'), 'hello');
    expect(prefs.getBool('a_bool'), true);
    expect(prefs.getInt('an_int'), 42);
    expect(prefs.getDouble('a_double'), 3.14);
    expect(prefs.getStringList('a_list'), ['x', 'y', 'z']);
  });

  test('import throws when no backup file exists', () async {
    expect(BackupService.import(), throwsException);
  });
}
