import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/import_reference_area.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

// Three streets of Villefranche-sur-Saône as the BAN lists them, and a
// lieu-dit without numbers.
final _nationale = BanStreetId('69264_1460');
final _gambetta = BanStreetId('69264_0682');
final _roses = BanStreetId('69264_0246');
final _lieuDit = BanStreetId('69264_1781');

DirectoryStreet _listed(BanStreetId id, String name, int count) =>
    DirectoryStreet(
      id: id,
      name: valueOf(StreetName.create(name)),
      numberCount: count,
    );

final _commune = CommuneStreets(
  commune: villefranche,
  streets: [
    _listed(_nationale, 'Rue Nationale', 2),
    _listed(_gambetta, 'Rue Gambetta', 1),
    _listed(_lieuDit, 'Les Grandes Terres', 0),
    _listed(_roses, 'Allée des Roses', 1),
  ],
  skippedStreets: 0,
);

StreetNumbers _numbers(
  BanStreetId id,
  String name,
  List<DirectoryNumber> numbers, {
  int invalid = 0,
  int duplicates = 0,
}) => StreetNumbers(
  id: id,
  name: valueOf(StreetName.create(name)),
  commune: villefranche,
  numbers: numbers,
  invalidNumbers: invalid,
  duplicateNumbers: duplicates,
);

final _nationaleNumbers = _numbers(
  _nationale,
  'Rue Nationale',
  [
    DirectoryNumber(number: n('2'), position: northDoor),
    DirectoryNumber(number: n('1'), position: townHallDoor),
  ],
  invalid: 1,
  duplicates: 2,
);
final _gambettaNumbers = _numbers(_gambetta, 'Rue Gambetta', [
  DirectoryNumber(number: n('3bis')),
]);
final _rosesNumbers = _numbers(_roses, 'Allée des Roses', [
  DirectoryNumber(number: n('4')),
]);
final _lieuDitNumbers = _numbers(_lieuDit, 'Les Grandes Terres', const []);

/// A directory that knows Villefranche-sur-Saône and its streets; [streets]
/// replaces the answers for some of them.
FakeAddressDirectory _directory({
  Map<BanStreetId, Result<StreetNumbers, AddressDirectoryFailure>> streets =
      const {},
}) => FakeAddressDirectory(
  communes: {'69264': Ok(_commune)},
  streets: {
    _nationale: Ok(_nationaleNumbers),
    _gambetta: Ok(_gambettaNumbers),
    _roses: Ok(_rosesNumbers),
    _lieuDit: Ok(_lieuDitNumbers),
    ...streets,
  },
);

void main() {
  late FakeStreetRepository streets;

  setUp(() => streets = FakeStreetRepository());

  ImportReferenceArea importWith(FakeAddressDirectory directory) =>
      ImportReferenceArea(directory, streets, FakeIdGenerator('street'));

  List<BanStreetId> idsOf(ImportReport report) => [
    for (final outcome in report.streets) outcome.banId,
  ];

  group('whole commune', () {
    test('should import every street the BAN gives numbers for', () async {
      final directory = _directory();

      final report = valueOf(await importWith(directory)(insee('69264')));

      expect(report.commune, villefranche);
      expect(idsOf(report), [_nationale, _gambetta, _roses]);
      expect(report.streets, everyElement(isA<StreetImported>()));
      expect(directory.communesAsked, ['69264']);
      expect(directory.streetsAsked, [_nationale, _gambetta, _roses]);
      expect(streets.added.map((street) => street.id.value), [
        'street-1',
        'street-2',
        'street-3',
      ]);
    });

    test(
      'should leave out the streets without numbers and count them',
      () async {
        final report = valueOf(await importWith(_directory())(insee('69264')));

        expect(report.emptyStreets, 1);
        expect(idsOf(report), isNot(contains(_lieuDit)));
        expect(report.unknownStreets, isEmpty);
      },
    );

    test('should import a street the BAN gives a single number for', () async {
      final report = valueOf(await importWith(_directory())(insee('69264')));

      // Rue Gambetta has a count of 1: the limit kept is 1, not 2.
      expect(idsOf(report), contains(_gambetta));
    });
  });

  group('the street made', () {
    test('should hold the numbers and positions of the BAN', () async {
      valueOf(
        await importWith(_directory())(insee('69264'), only: [_nationale]),
      );

      final street = streets.added.single;
      expect(street.id, StreetId('street-1'));
      expect(street.name.text, 'Rue Nationale');
      expect(street.commune, villefranche);
      expect(street.banId, _nationale);
      expect(street.isDeleted, isFalse);
      expect(street.removedHouses, isEmpty);
      expect(street.houses, [
        House(number: n('1'), position: townHallDoor),
        House(number: n('2'), position: northDoor),
      ]);
    });

    test('should report what it kept and what the BAN gave unread', () async {
      final report = valueOf(
        await importWith(_directory())(insee('69264'), only: [_nationale]),
      );

      final imported = report.streets.single as StreetImported;
      expect(imported.banId, _nationale);
      expect(imported.streetId, StreetId('street-1'));
      expect(imported.numberCount, 2);
      expect(imported.skippedNumbers, 3);
    });

    test('should import a chosen street even without numbers', () async {
      final report = valueOf(
        await importWith(_directory())(insee('69264'), only: [_lieuDit]),
      );

      final imported = report.streets.single as StreetImported;
      expect(imported.numberCount, 0);
      expect(imported.skippedNumbers, 0);
      expect(streets.added.single.houses, isEmpty);
      expect(report.emptyStreets, 0);
    });
  });

  group('chosen streets', () {
    test('should import only the chosen streets, in the BAN order', () async {
      final directory = _directory();

      final report = valueOf(
        await importWith(directory)(insee('69264'), only: [_roses, _nationale]),
      );

      expect(idsOf(report), [_nationale, _roses]);
      expect(directory.streetsAsked, [_nationale, _roses]);
    });

    test('should report the chosen ids the commune does not list', () async {
      final elsewhere = BanStreetId('69264_9999');

      final report = valueOf(
        await importWith(_directory())(
          insee('69264'),
          only: [elsewhere, _roses],
        ),
      );

      expect(report.unknownStreets, [elsewhere]);
      expect(idsOf(report), [_roses]);
    });
  });

  group('re-import', () {
    test('should leave a street already imported as it is', () async {
      final first = importWith(_directory());
      valueOf(await first(insee('69264'), only: [_gambetta]));
      final imported = streets.added.single;
      final (marked, change) = valueOf(
        imported.markHouse(n('3bis'), VisitStatus.done, by: lea, at: twoPm),
      );
      await streets.save(marked, change);
      final directory = _directory();

      final report = valueOf(
        await importWith(directory)(insee('69264'), only: [_gambetta]),
      );

      final already = report.streets.single as StreetAlreadyImported;
      expect(already.banId, _gambetta);
      expect(already.streetId, imported.id);
      expect(report.commune, villefranche);
      expect(directory.communesAsked, isEmpty);
      expect(directory.streetsAsked, isEmpty);
      expect(streets.added, hasLength(1));
      expect(streets.saved, hasLength(1));
      expect(streets[imported.id], same(marked));
    });
  });

  group('from the Corbeille', () {
    /// Rue Gambetta, imported, its 3bis « repasser » after 19h, then sent
    /// to the Corbeille.
    Street deletedGambetta() => valueOf(
      Street.create(
        id: StreetId('gambetta'),
        name: 'Rue Gambetta',
        commune: villefranche,
        banId: _gambetta,
        houses: [
          House(
            number: n('3bis'),
            status: VisitStatus.comeBack,
            comeBack: comeBack('après 19h'),
          ),
        ],
      ),
    ).delete(by: lea, at: twoPm).$1;

    test('should bring the street back with its marks', () async {
      final deleted = deletedGambetta();
      streets = FakeStreetRepository([deleted]);

      final report = valueOf(
        await importWith(_directory())(insee('69264'), only: [_gambetta]),
      );

      final restored = report.streets.single as StreetRestoredFromCorbeille;
      expect(restored.banId, _gambetta);
      expect(restored.streetId, StreetId('gambetta'));
      final (saved, change) = streets.saved.single;
      expect(change, StreetRestored(streetId: StreetId('gambetta')));
      expect(saved.isDeleted, isFalse);
      expect(saved.houses, deleted.houses);
      expect(saved.houses.single.status, VisitStatus.comeBack);
      expect(saved.houses.single.comeBack, comeBack('après 19h'));
      expect(streets.added, isEmpty);
    });

    test('should not ask the BAN for it', () async {
      streets = FakeStreetRepository([deletedGambetta()]);
      final directory = _directory();

      final report = valueOf(
        await importWith(directory)(insee('69264'), only: [_gambetta]),
      );

      expect(report.commune, villefranche);
      expect(report.unknownStreets, isEmpty);
      expect(directory.communesAsked, isEmpty);
      expect(directory.streetsAsked, isEmpty);
    });

    test('should bring it back when the BAN is unreachable', () async {
      streets = FakeStreetRepository([deletedGambetta()]);
      final directory = FakeAddressDirectory(
        communes: {'69264': const Err(AddressDirectoryFailure.noNetwork)},
      );

      final report = valueOf(
        await importWith(directory)(insee('69264'), only: [_gambetta]),
      );

      expect(report.streets.single, isA<StreetRestoredFromCorbeille>());
      expect(streets[StreetId('gambetta')]!.isDeleted, isFalse);
    });

    test(
      'should fail the other chosen streets when the BAN is unreachable',
      () async {
        streets = FakeStreetRepository([deletedGambetta()]);
        final directory = FakeAddressDirectory(
          communes: {'69264': const Err(AddressDirectoryFailure.noNetwork)},
        );

        final report = valueOf(
          await importWith(directory)(
            insee('69264'),
            only: [_roses, _gambetta],
          ),
        );

        expect(report.commune, villefranche);
        expect(report.streets[0], isA<StreetRestoredFromCorbeille>());
        final failed = report.streets[1] as StreetImportFailed;
        expect(failed.banId, _roses);
        expect(failed.failure, AddressDirectoryFailure.noNetwork);
        expect(report.streets, hasLength(2));
        expect(streets.added, isEmpty);
      },
    );

    test('should download only the chosen streets not on the phone', () async {
      streets = FakeStreetRepository([deletedGambetta()]);
      final directory = _directory();
      final steps = <(int, int)>[];

      final report = valueOf(
        await importWith(directory)(
          insee('69264'),
          only: [_roses, _gambetta],
          onProgress: (done, total) => steps.add((done, total)),
        ),
      );

      expect(idsOf(report), [_gambetta, _roses]);
      expect(report.streets.last, isA<StreetImported>());
      expect(directory.streetsAsked, [_roses]);
      expect(steps, [(2, 2)]);
    });

    test('should bring it back when the whole commune is imported', () async {
      streets = FakeStreetRepository([deletedGambetta()]);
      final directory = _directory();

      final report = valueOf(await importWith(directory)(insee('69264')));

      expect(report.streets[1], isA<StreetRestoredFromCorbeille>());
      expect(directory.streetsAsked, [_nationale, _roses]);
      expect(streets[StreetId('gambetta')]!.isDeleted, isFalse);
    });
  });

  group('failures', () {
    test('should fail as a whole when the commune cannot be listed', () async {
      final directory = FakeAddressDirectory(
        communes: {'69264': const Err(AddressDirectoryFailure.notFound)},
      );

      final failure = failureOf(await importWith(directory)(insee('69264')));

      expect(failure, AddressDirectoryFailure.notFound);
      expect(directory.streetsAsked, isEmpty);
      expect(streets.added, isEmpty);
    });

    test('should report a street the BAN refuses and go on', () async {
      final report = valueOf(
        await importWith(
          _directory(
            streets: {_gambetta: const Err(AddressDirectoryFailure.notFound)},
          ),
        )(insee('69264')),
      );

      final failed = report.streets[1] as StreetImportFailed;
      expect(failed.banId, _gambetta);
      expect(failed.failure, AddressDirectoryFailure.notFound);
      expect(report.streets[2], isA<StreetImported>());
      expect(streets.added.map((street) => street.banId), [_nationale, _roses]);
    });

    test('should report a service error and go on', () async {
      final directory = _directory(
        streets: {_nationale: const Err(AddressDirectoryFailure.serviceError)},
      );

      final report = valueOf(await importWith(directory)(insee('69264')));

      expect(
        (report.streets.first as StreetImportFailed).failure,
        AddressDirectoryFailure.serviceError,
      );
      expect(directory.streetsAsked, [_nationale, _gambetta, _roses]);
    });

    test('should not try the next streets once the network is gone', () async {
      final directory = _directory(
        streets: {_gambetta: const Err(AddressDirectoryFailure.noNetwork)},
      );

      final report = valueOf(await importWith(directory)(insee('69264')));

      expect(report.streets[0], isA<StreetImported>());
      expect(
        [
          for (final outcome in report.streets.skip(1))
            (outcome as StreetImportFailed).failure,
        ],
        [AddressDirectoryFailure.noNetwork, AddressDirectoryFailure.noNetwork],
      );
      expect(directory.streetsAsked, [_nationale, _gambetta]);
    });

    test(
      'should still report the streets already there once offline',
      () async {
        streets = FakeStreetRepository([
          valueOf(
            Street.create(
              id: StreetId('roses'),
              name: 'Allée des Roses',
              commune: villefranche,
              banId: _roses,
            ),
          ),
        ]);
        final directory = _directory(
          streets: {_gambetta: const Err(AddressDirectoryFailure.noNetwork)},
        );

        final report = valueOf(await importWith(directory)(insee('69264')));

        expect(report.streets.last, isA<StreetAlreadyImported>());
      },
    );

    test('should report as unreadable a street it cannot make', () async {
      final twice = _numbers(_roses, 'Allée des Roses', [
        DirectoryNumber(number: n('4')),
        DirectoryNumber(number: n('4')),
      ]);

      final report = valueOf(
        await importWith(_directory(streets: {_roses: Ok(twice)}))(
          insee('69264'),
          only: [_roses],
        ),
      );

      expect(
        (report.streets.single as StreetImportFailed).failure,
        AddressDirectoryFailure.serviceError,
      );
      expect(streets.added, isEmpty);
    });
  });

  group('progress', () {
    test('should tell after each street how many are done', () async {
      final steps = <(int, int)>[];

      await importWith(_directory())(
        insee('69264'),
        onProgress: (done, total) => steps.add((done, total)),
      );

      expect(steps, [(1, 3), (2, 3), (3, 3)]);
    });
  });

  group('report', () {
    test('should give lists nobody can change', () async {
      final report = valueOf(await importWith(_directory())(insee('69264')));

      expect(report.streets.clear, throwsUnsupportedError);
      expect(report.unknownStreets.clear, throwsUnsupportedError);
    });
  });
}
