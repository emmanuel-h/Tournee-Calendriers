import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/bootstrap/cache_reset.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/cache_reset_json_mapper.dart';

/// An in-memory Firestore that also says when the server has every write
/// (fake_cloud_firestore has no server, so: at once).
final class _Db extends FakeFirebaseFirestore {
  var cleared = 0;
  var waited = 0;

  @override
  Future<void> clearPersistence() {
    cleared++;
    return super.clearPersistence();
  }

  @override
  Future<void> waitForPendingWrites() async => waited++;
}

void main() {
  // `AppLifecycleListener` registers with Flutter's binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory storage;
  late _Db db;
  late int asked;

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('cache_reset_boot_test');
    db = _Db();
    asked = 0;
  });

  tearDown(() => storage.delete(recursive: true));

  File fileOf(String name) => File('${storage.path}/$name');

  void store(CacheResetStep step) =>
      fileOf('cache_reset.json')
          .writeAsStringSync(jsonEncode(cacheResetToJson(step)));

  CacheResetStep stored() => cacheResetFromJson(
    jsonDecode(fileOf('cache_reset.json').readAsStringSync()),
  );

  Future<void> start({bool online = true}) => startCacheReset(
    storage: storage,
    firestore: () {
      asked++;
      return db;
    },
    online: () async => online,
  );

  test('should name the file of the downloads', () {
    expect(sectorDownloadsFile, 'tournee_downloads.json');
  });

  test('should empty the copy and forget the downloads when a reset is '
      'due', () async {
    store(CacheResetStep.due);
    fileOf(sectorDownloadsFile).writeAsStringSync('{}');

    await start();

    expect(db.cleared, 1);
    expect(fileOf(sectorDownloadsFile).existsSync(), isFalse);
    expect(stored(), CacheResetStep.none);
  });

  test('should empty the copy when no download was kept', () async {
    store(CacheResetStep.due);

    await start();

    expect(db.cleared, 1);
    expect(stored(), CacheResetStep.none);
  });

  test('should keep the copy and the downloads offline', () async {
    store(CacheResetStep.due);
    fileOf(sectorDownloadsFile).writeAsStringSync('{}');

    await start(online: false);

    expect(db.cleared, 0);
    expect(fileOf(sectorDownloadsFile).existsSync(), isTrue);
    expect(stored(), CacheResetStep.due);
  });

  test('should not touch Firestore when nothing is asked', () async {
    await start();

    expect(asked, 0);
    expect(fileOf('cache_reset.json').existsSync(), isFalse);
  });

  test('should wait for the server again each time the app is '
      'hidden', () async {
    store(CacheResetStep.due);
    await start(online: false);

    // A phone is hidden through `inactive` then `hidden`.
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    while (db.waited == 0) {
      await pumpEventQueue();
    }
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(db.waited, 1);
  });
}
