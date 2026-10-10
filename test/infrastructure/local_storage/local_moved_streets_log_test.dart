import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_moved_streets_log.dart';

void main() {
  late Directory folder;
  late File file;
  final t49 = TourneeId('t49');
  final t12 = TourneeId('t12');

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('moved_streets_test');
    // In a folder not made yet, as on a first launch.
    file = File('${folder.path}/storage/moved_streets.json');
  });

  tearDown(() => folder.delete(recursive: true));

  test('should know no tournée when the file does not exist', () async {
    final log = await LocalMovedStreetsLog.load(file);

    expect(log.wereMovedInto(t49), isFalse);
    expect(file.existsSync(), isFalse);
  });

  test('should answer at once and keep the tournée on the phone', () async {
    final log = await LocalMovedStreetsLog.load(file);

    final saving = log.rememberMovedInto(t49);
    expect(log.wereMovedInto(t49), isTrue);
    await saving;

    expect(jsonDecode(file.readAsStringSync()), {
      'version': 1,
      'movedInto': ['t49'],
    });
    final reloaded = await LocalMovedStreetsLog.load(file);
    expect(reloaded.wereMovedInto(t49), isTrue);
    expect(reloaded.wereMovedInto(t12), isFalse);
  });

  test('should keep every tournée the streets went into', () async {
    final log = await LocalMovedStreetsLog.load(file);

    await Future.wait([log.rememberMovedInto(t49), log.rememberMovedInto(t12)]);

    final reloaded = await LocalMovedStreetsLog.load(file);
    expect(reloaded.wereMovedInto(t49), isTrue);
    expect(reloaded.wereMovedInto(t12), isTrue);
  });

  test('should know no tournée when the file is unreadable', () async {
    await file.parent.create(recursive: true);
    file.writeAsStringSync('{"version": 9}');

    final log = await LocalMovedStreetsLog.load(file);

    expect(log.wereMovedInto(t49), isFalse);
    await log.rememberMovedInto(t12);
    expect(jsonDecode(file.readAsStringSync()), {
      'version': 1,
      'movedInto': ['t12'],
    });
  });

  test('should know no tournée when the file is not JSON', () async {
    await file.parent.create(recursive: true);
    file.writeAsStringSync('not json');

    final log = await LocalMovedStreetsLog.load(file);

    expect(log.wereMovedInto(t49), isFalse);
  });
}
