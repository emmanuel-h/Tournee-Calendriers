import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_my_sectors.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/my_sectors_json_mapper.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/results.dart';

void main() {
  late Directory folder;
  late File file;

  /// The 49, open, and the 12.
  final twoSectors = valueOf(
    MySectors.none.remember(sector49).remember(sector12).open(sector49.id),
  );

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('my_sectors_test');
    // In a folder not made yet, as on a first launch.
    file = File('${folder.path}/storage/my_tournees.json');
  });

  tearDown(() => folder.delete(recursive: true));

  test('should know no tournée when the file does not exist', () async {
    final store = await LocalMySectors.load(file);

    expect(store.mySectors, MySectors.none);
    expect(file.existsSync(), isFalse);
  });

  test('should answer at once, tell listeners and keep the list on the '
      'phone', () async {
    final store = await LocalMySectors.load(file);
    final heard = <MySectors>[];
    store.changes.listen(heard.add);

    final saving = store.save(twoSectors);
    expect(store.mySectors, twoSectors);
    await saving;

    expect(heard, [twoSectors]);
    expect(jsonDecode(file.readAsStringSync()), mySectorsToJson(twoSectors));
  });

  test('should open the last tournée again at the next launch', () async {
    final first = await LocalMySectors.load(file);
    await first.save(twoSectors);
    await first.save(valueOf(twoSectors.open(sector12.id)));

    final next = await LocalMySectors.load(file);

    expect(next.mySectors.current, sector12);
    expect(next.mySectors.sectors, [sector49, sector12]);
  });

  test(
    'should know no tournée and leave the file when it is not ours',
    () async {
      await file.parent.create(recursive: true);
      file.writeAsStringSync('{"version": 9}');

      final store = await LocalMySectors.load(file);

      expect(store.mySectors, MySectors.none);
      expect(file.readAsStringSync(), '{"version": 9}');
    },
  );

  test('should know no tournée when the file is not JSON', () async {
    await file.parent.create(recursive: true);
    file.writeAsBytesSync([0xff, 0xfe, 0x00]);

    final store = await LocalMySectors.load(file);

    expect(store.mySectors, MySectors.none);
  });
}
