// The phone storage of M1 on a real temporary folder: what is written must
// be there after a restart (a new repository on the same folder), whatever
// happened in between.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/mark_house.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/street_json_mapper.dart';

import '../../support/fakes/fake_ports.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'stored_street_fixtures.dart';

Street _street(String id, String name, {String? banId}) => valueOf(
  Street.create(
    id: StreetId(id),
    name: name,
    commune: villefranche,
    banId: banId == null ? null : BanStreetId(banId),
    houses: [
      House(number: n('1')),
      House(number: n('2')),
    ],
  ),
);

void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('streets_test');
  });

  tearDown(() => folder.delete(recursive: true));

  /// A repository on [folder]; a new one simulates a restart of the app.
  LocalStreetRepository restart() =>
      LocalStreetRepository(Directory('${folder.path}/streets'));

  List<String> fileNames() => [
    for (final entity in Directory('${folder.path}/streets').listSync())
      entity.uri.pathSegments.last,
  ]..sort();

  group('restart', () {
    test('should find nothing and make its folder when it is new', () async {
      final streets = restart();

      expect(await streets.find(StreetId('lilas')), isNull);
      expect(Directory('${folder.path}/streets').existsSync(), isTrue);
    });

    test('should give back a full street after a restart', () async {
      await restart().add(richStreet);

      final found = await restart().find(richStreet.id);

      expectSameStreet(found!, richStreet);
    });

    test('should keep the marks after a restart', () async {
      final streets = restart();
      final lilas = _street('lilas', 'Rue des Lilas');
      await streets.add(lilas);
      final (marked, change) = valueOf(
        lilas.markHouse(n('2'), VisitStatus.done, by: lea, at: twoPm),
      );
      await streets.save(marked, change);

      final found = await restart().find(StreetId('lilas'));

      expect(found!.houses.last.status, VisitStatus.done);
      expect(found.houses.last.lastChange, leaAtTwo);
    });

    test('should keep the last of quick saves in a row', () async {
      final streets = restart();
      var street = _street('lilas', 'Rue des Lilas');
      await streets.add(street);
      final saves = <Future<void>>[];
      for (final status in [
        VisitStatus.done,
        VisitStatus.nobodyHome,
        VisitStatus.toDo,
        VisitStatus.done,
      ]) {
        final (marked, change) = valueOf(
          street.markHouse(n('1'), status, by: lea, at: twoPm),
        );
        street = marked;
        saves.add(streets.save(marked, change));
      }
      await Future.wait(saves);

      final found = await restart().find(StreetId('lilas'));

      expect(found!.houses.first.status, VisitStatus.done);
    });

    test('should keep two quick taps on two houses', () async {
      final streets = restart();
      await streets.add(_street('lilas', 'Rue des Lilas'));
      final markHouse = MarkHouse(streets, FakeClock(twoPm), FakeIdentity(lea));

      // Two taps are two events: the second comes on a later turn of the
      // event loop, while the first one's file may still be written.
      final first = markHouse(StreetId('lilas'), n('1'), VisitStatus.done);
      await Future<void>.delayed(Duration.zero);
      final second = markHouse(StreetId('lilas'), n('2'), VisitStatus.done);
      await Future.wait([first, second]);

      final found = await restart().find(StreetId('lilas'));
      expect(found!.houses.map((house) => house.status), [
        VisitStatus.done,
        VisitStatus.done,
      ]);
    });

    test('should serve a saved street before its file is written', () async {
      final streets = restart();
      final lilas = _street('lilas', 'Rue des Lilas');
      await streets.add(lilas);
      final (marked, change) = valueOf(
        lilas.markHouse(n('1'), VisitStatus.done, by: lea, at: twoPm),
      );

      final saving = streets.save(marked, change);
      final found = await streets.find(StreetId('lilas'));
      await saving;

      expect(found, same(marked));
    });
  });

  group('files', () {
    test('should write one file per street and no temporary file', () async {
      final streets = restart();
      await streets.add(_street('lilas', 'Rue des Lilas'));
      await streets.add(_street('roses', 'Allée des Roses'));

      expect(fileNames(), ['lilas.json', 'roses.json']);
    });

    test('should write the stored form of the street', () async {
      await restart().add(manualStreet);

      final text = File('${folder.path}/streets/manual-1.json')
          .readAsStringSync();

      expect(jsonDecode(text), streetToJson(manualStreet));
    });

    test('should keep an odd id inside its folder', () async {
      await restart().add(_street('a/b c', 'Rue des Lilas'));

      expect(fileNames(), ['a%2Fb%20c.json']);
      expect(await restart().find(StreetId('a/b c')), isNotNull);
    });

    test('should ignore the temporary file of a killed write', () async {
      await restart().add(_street('lilas', 'Rue des Lilas'));
      File('${folder.path}/streets/lilas.json.tmp')
          .writeAsStringSync('{"version": 1, "id": "lil');

      final found = await restart().find(StreetId('lilas'));

      expect(found!.name.text, 'Rue des Lilas');
    });

    test('should skip an unreadable file and leave it as it is', () async {
      await restart().add(_street('lilas', 'Rue des Lilas'));
      final broken = File('${folder.path}/streets/broken.json')
        ..writeAsStringSync('{"version": 99}');
      File('${folder.path}/streets/latin1.json')
          .writeAsBytesSync([0x7b, 0xe9, 0x7d]);
      Directory('${folder.path}/streets/folder.json').createSync();

      final all = await restart().watchAll().first;

      expect(all.map((street) => street.id.value), ['lilas']);
      expect(broken.readAsStringSync(), '{"version": 99}');
    });

    group('of an older schema', () {
      const id = 'x7Kq2LmP9sTb4VnW1cZd';
      File stored() => File('${folder.path}/streets/$id.json');

      /// Puts the fixture [name] in the folder as the file of its street.
      String put(String name) {
        final text = File('test/fixtures/local_storage/$name')
            .readAsStringSync();
        Directory('${folder.path}/streets').createSync();
        stored().writeAsStringSync(text);
        return text;
      }

      /// Reads the streets, then waits for the writes the reading asked:
      /// writes run in order, so once a later one is done they are too.
      Future<void> readThenWait() async {
        final streets = restart();
        await streets.find(StreetId(id));
        await streets.add(_street('lilas', 'Rue des Lilas'));
      }

      test('should write a version 2 file again in version 3 when read, '
          'without its notes', () async {
        put('street_v2.json');

        await readThenWait();

        final written = jsonDecode(stored().readAsStringSync());
        expect((written as Map<String, Object?>)['version'], 3);
        expect(stored().readAsStringSync(), isNot(contains('"note"')));
        expect(
          written,
          jsonDecode(
            jsonEncode(
              streetToJson(
                streetFromJson(
                  jsonDecode(
                    File('test/fixtures/local_storage/street_v3.json')
                        .readAsStringSync(),
                  ),
                ),
              ),
            ),
          ),
        );
      });

      test(
        'should write a version 1 file again in version 3 when read',
        () async {
          put('street_v1.json');

          await readThenWait();

          expect(stored().readAsStringSync(), isNot(contains('"note"')));
          expect(stored().readAsStringSync(), contains('"version":3'));
        },
      );

      test('should leave a version 3 file as it is when read', () async {
        final text = put('street_v3.json');

        await readThenWait();

        expect(stored().readAsStringSync(), text);
      });

      test('should keep the old file and go on when writing it again '
          'fails', () async {
        final text = put('street_v2.json');
        // A folder where the temporary file should go makes the write fail.
        Directory('${stored().path}.tmp').createSync();

        await readThenWait();

        expect(stored().readAsStringSync(), text);
        expect(await restart().find(StreetId('lilas')), isNotNull);
      });
    });

    test('should report a folder it cannot make', () async {
      File('${folder.path}/streets').writeAsStringSync('not a folder');

      await expectLater(restart().find(StreetId('lilas')), throwsA(anything));
      await expectLater(restart().watchAll().first, throwsA(anything));
    });
  });

  group('findByBanId', () {
    test('should find the street imported from a BAN street', () async {
      final streets = restart();
      await streets.add(_street('lilas', 'Rue des Lilas', banId: '69264_0420'));
      await streets.add(
        _street('roses', 'Allée des Roses', banId: '69264_0246'),
      );

      final found = await streets.findByBanId(BanStreetId('69264_0246'));

      expect(found!.id, StreetId('roses'));
    });

    test('should find it in the Corbeille too', () async {
      final streets = restart();
      final (deleted, change) = _street(
        'lilas',
        'Rue des Lilas',
        banId: '69264_0420',
      ).delete(by: lea, at: twoPm);
      await streets.add(deleted);

      final found = await streets.findByBanId(BanStreetId('69264_0420'));

      expect(found!.isDeleted, isTrue);
      expect(change.streetId, StreetId('lilas'));
    });

    test('should find nothing when no street came from it', () async {
      final streets = restart();
      await streets.add(_street('lilas', 'Rue des Lilas'));

      expect(await streets.findByBanId(BanStreetId('69264_0420')), isNull);
    });
  });

  group('watch', () {
    test('should give the street now and after each of its changes', () async {
      final streets = restart();
      final lilas = _street('lilas', 'Rue des Lilas');
      await streets.add(lilas);
      await streets.add(_street('roses', 'Allée des Roses'));
      final seen = <Street?>[];
      final subscription = streets.watch(StreetId('lilas')).listen(seen.add);
      await pumpEventQueue();

      final (marked, change) = valueOf(
        lilas.markHouse(n('1'), VisitStatus.done, by: lea, at: twoPm),
      );
      await streets.save(marked, change);
      await streets.add(_street('gare', 'Avenue de la Gare'));
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [same(lilas), same(marked)]);
    });

    test('should give null while the street is not there', () async {
      final streets = restart();
      final seen = <Street?>[];
      final subscription = streets.watch(StreetId('lilas')).listen(seen.add);
      await pumpEventQueue();

      final lilas = _street('lilas', 'Rue des Lilas');
      await streets.add(lilas);
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [isNull, same(lilas)]);
    });

    test('should give nothing when left before the files are read', () async {
      final streets = restart();
      final seen = <Street?>[];

      await streets.watch(StreetId('lilas')).listen(seen.add).cancel();
      await pumpEventQueue();
      await streets.add(_street('lilas', 'Rue des Lilas'));
      await pumpEventQueue();

      expect(seen, isEmpty);
    });
  });

  group('watchAll', () {
    test('should list the streets not in the Corbeille, live', () async {
      final streets = restart();
      final lilas = _street('lilas', 'Rue des Lilas');
      await streets.add(lilas);
      final seen = <List<String>>[];
      final subscription = streets.watchAll().listen(
        (all) => seen.add([for (final street in all) street.id.value]),
      );
      await pumpEventQueue();

      await streets.add(_street('roses', 'Allée des Roses'));
      final (deleted, change) = lilas.delete(by: lea, at: twoPm);
      await streets.save(deleted, change);
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [
        ['lilas'],
        unorderedEquals(['lilas', 'roses']),
        ['roses'],
      ]);
    });

    test('should give a list nobody can change', () async {
      final streets = restart();
      await streets.add(_street('lilas', 'Rue des Lilas'));

      final all = await streets.watchAll().first;

      expect(all.clear, throwsUnsupportedError);
    });
  });

  group('watchDeleted', () {
    test('should list the streets in the Corbeille, live', () async {
      final streets = restart();
      final lilas = _street('lilas', 'Rue des Lilas');
      final roses = _street('roses', 'Allée des Roses');
      await streets.add(lilas);
      await streets.add(roses);
      final seen = <List<String>>[];
      final subscription = streets.watchDeleted().listen(
        (deleted) => seen.add([for (final street in deleted) street.id.value]),
      );
      await pumpEventQueue();

      final (deleted, change) = lilas.delete(by: lea, at: twoPm);
      await streets.save(deleted, change);
      final (restored, back) = deleted.restore();
      await streets.save(restored, back);
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [
        isEmpty,
        ['lilas'],
        isEmpty,
      ]);
    });

    test('should give a list nobody can change', () async {
      final streets = restart();
      final (deleted, _) = _street(
        'lilas',
        'Rue des Lilas',
      ).delete(by: lea, at: twoPm);
      await streets.add(deleted);

      final all = await streets.watchDeleted().first;

      expect(all.single.id.value, 'lilas');
      expect(all.clear, throwsUnsupportedError);
    });
  });
}
