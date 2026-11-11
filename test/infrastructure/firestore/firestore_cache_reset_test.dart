import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_cache_reset.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/cache_reset_json_mapper.dart';

void main() {
  late Directory folder;
  late File file;

  /// Each wait for the server asked, to end (or fail) by hand.
  late List<Completer<void>> waits;

  /// How many times Firestore's copy was emptied.
  late int clears;

  /// What emptying the copy does: nothing, or throw this.
  Error? clearFails;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('cache_reset_test');
    // In a folder not made yet, as on a first launch.
    file = File('${folder.path}/storage/cache_reset.json');
    waits = [];
    clears = 0;
    clearFails = null;
  });

  tearDown(() => folder.delete(recursive: true));

  Future<FirestoreCacheReset> load() => FirestoreCacheReset.load(
    file,
    waitForPendingWrites: () {
      final wait = Completer<void>();
      waits.add(wait);
      return wait.future;
    },
    clearPersistence: () async {
      if (clearFails case final error?) throw error;
      clears++;
    },
  );

  CacheResetStep stored() =>
      cacheResetFromJson(jsonDecode(file.readAsStringSync()));

  void store(CacheResetStep step) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(cacheResetToJson(step)));
  }

  /// Empties the copy if due, online by default; counts the runs of the
  /// step after it.
  var afterResets = 0;
  Future<bool> resetIfDue(FirestoreCacheReset reset, {bool online = true}) =>
      reset.resetIfDue(
        online: () async => online,
        afterReset: () async => afterResets++,
      );

  setUp(() => afterResets = 0);

  group('load', () {
    test('should ask nothing when there is no file', () async {
      final reset = await load();

      expect(reset.step, CacheResetStep.none);
      expect(file.existsSync(), isFalse);
    });

    test('should read the step kept on the phone', () async {
      store(CacheResetStep.due);

      expect((await load()).step, CacheResetStep.due);
    });

    test('should ask nothing when the file cannot be read', () async {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{"version": 9}');

      expect((await load()).step, CacheResetStep.none);
    });
  });

  group('scheduleAtNextStart', () {
    test('should wait for the server, then make the reset due', () async {
      final reset = await load();

      reset.scheduleAtNextStart();
      expect(reset.step, CacheResetStep.waiting);
      // The step is on the phone before the server answers: a kill now
      // empties nothing.
      while (waits.isEmpty) {
        await pumpEventQueue();
      }
      expect(stored(), CacheResetStep.waiting);

      waits.single.complete();
      await reset.lastWait;

      expect(reset.step, CacheResetStep.due);
      expect(stored(), CacheResetStep.due);
    });

    test('should stay waiting while the server has not every change', () async {
      final reset = await load();

      reset.scheduleAtNextStart();
      while (waits.isEmpty) {
        await pumpEventQueue();
      }
      waits.single.completeError(StateError('Firestore terminated'));
      await reset.lastWait;

      expect(reset.step, CacheResetStep.waiting);
      expect(stored(), CacheResetStep.waiting);
    });

    test('should not let an older wait make the reset due', () async {
      final reset = await load();

      reset.scheduleAtNextStart();
      while (waits.isEmpty) {
        await pumpEventQueue();
      }
      reset.appHidden();
      while (waits.length < 2) {
        await pumpEventQueue();
      }
      // The first wait does not cover what was written between the two.
      waits.first.complete();
      await pumpEventQueue();
      expect(reset.step, CacheResetStep.waiting);

      waits.last.complete();
      await reset.lastWait;
      expect(reset.step, CacheResetStep.due);
      expect(stored(), CacheResetStep.due);
    });
  });

  group('appHidden', () {
    test('should do nothing when no reset is asked', () async {
      final reset = await load();

      reset.appHidden();
      await reset.lastWait;

      expect(reset.step, CacheResetStep.none);
      expect(waits, isEmpty);
      expect(file.existsSync(), isFalse);
    });

    test('should wait again for the server when a reset is due', () async {
      store(CacheResetStep.due);
      final reset = await load();

      reset.appHidden();

      expect(reset.step, CacheResetStep.waiting);
      while (waits.isEmpty) {
        await pumpEventQueue();
      }
      expect(stored(), CacheResetStep.waiting);
      waits.single.complete();
      await reset.lastWait;
      expect(stored(), CacheResetStep.due);
    });

    test('should wait again for the server when a reset still waits', () async {
      store(CacheResetStep.waiting);
      final reset = await load();

      reset.appHidden();
      while (waits.isEmpty) {
        await pumpEventQueue();
      }
      waits.single.complete();
      await reset.lastWait;

      expect(reset.step, CacheResetStep.due);
    });
  });

  group('resetIfDue', () {
    test('should empty the copy, run the step after it and ask nothing any '
        'more when due and online', () async {
      store(CacheResetStep.due);
      final reset = await load();

      expect(await resetIfDue(reset), isTrue);

      expect(clears, 1);
      expect(afterResets, 1);
      expect(reset.step, CacheResetStep.none);
      expect(stored(), CacheResetStep.none);
    });

    test('should keep the copy while offline', () async {
      store(CacheResetStep.due);
      final reset = await load();

      expect(await resetIfDue(reset, online: false), isFalse);

      expect(clears, 0);
      expect(afterResets, 0);
      expect(reset.step, CacheResetStep.due);
    });

    test('should keep the copy while changes may wait to be sent', () async {
      store(CacheResetStep.waiting);
      final reset = await load();

      expect(await resetIfDue(reset), isFalse);

      expect(clears, 0);
      expect(reset.step, CacheResetStep.waiting);
    });

    test('should keep the copy when nothing is asked', () async {
      final reset = await load();

      expect(await resetIfDue(reset), isFalse);

      expect(clears, 0);
      expect(file.existsSync(), isFalse);
    });

    test('should keep the reset due when Firestore has started', () async {
      store(CacheResetStep.due);
      clearFails = StateError('Persistence cannot be cleared while running');
      final reset = await load();

      expect(await resetIfDue(reset), isFalse);

      expect(afterResets, 0);
      expect(reset.step, CacheResetStep.due);
      expect(stored(), CacheResetStep.due);
    });
  });
}
