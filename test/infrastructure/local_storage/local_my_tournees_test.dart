import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_my_tournees.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/my_tournees_json_mapper.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../support/results.dart';

void main() {
  late Directory folder;
  late File file;

  /// The 49, open, and the 12.
  final twoTournees = valueOf(
    MyTournees.none.remember(tournee49).remember(tournee12).open(tournee49.id),
  );

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('my_tournees_test');
    // In a folder not made yet, as on a first launch.
    file = File('${folder.path}/storage/my_tournees.json');
  });

  tearDown(() => folder.delete(recursive: true));

  test('should know no tournée when the file does not exist', () async {
    final store = await LocalMyTournees.load(file);

    expect(store.myTournees, MyTournees.none);
    expect(file.existsSync(), isFalse);
  });

  test('should answer at once, tell listeners and keep the list on the '
      'phone', () async {
    final store = await LocalMyTournees.load(file);
    final heard = <MyTournees>[];
    store.changes.listen(heard.add);

    final saving = store.save(twoTournees);
    expect(store.myTournees, twoTournees);
    await saving;

    expect(heard, [twoTournees]);
    expect(jsonDecode(file.readAsStringSync()), myTourneesToJson(twoTournees));
  });

  test('should open the last tournée again at the next launch', () async {
    final first = await LocalMyTournees.load(file);
    await first.save(twoTournees);
    await first.save(valueOf(twoTournees.open(tournee12.id)));

    final next = await LocalMyTournees.load(file);

    expect(next.myTournees.current, tournee12);
    expect(next.myTournees.tournees, [tournee49, tournee12]);
  });

  test(
    'should know no tournée and leave the file when it is not ours',
    () async {
      await file.parent.create(recursive: true);
      file.writeAsStringSync('{"version": 9}');

      final store = await LocalMyTournees.load(file);

      expect(store.myTournees, MyTournees.none);
      expect(file.readAsStringSync(), '{"version": 9}');
    },
  );

  test('should know no tournée when the file is not JSON', () async {
    await file.parent.create(recursive: true);
    file.writeAsBytesSync([0xff, 0xfe, 0x00]);

    final store = await LocalMyTournees.load(file);

    expect(store.myTournees, MyTournees.none);
  });
}
