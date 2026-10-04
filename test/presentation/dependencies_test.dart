// The providers wire each use case to the ports bound in the container: a
// call through a provider must reach the fakes given as overrides.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/application/use_cases/import_reference_area.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../application/use_cases/street_fixtures.dart';
import '../support/fakes/fake_address_directory.dart';
import '../support/fakes/fake_commune_search.dart';
import '../support/fakes/fake_ports.dart';
import '../support/fakes/fake_street_repository.dart';
import '../support/results.dart';
import '../support/street_fixtures.dart';

void main() {
  late FakeStreetRepository streets;
  late FakeAddressDirectory directory;
  late FakeCommuneSearch communes;
  late ProviderContainer container;

  setUp(() {
    streets = repositoryWithLilas();
    directory = FakeAddressDirectory(
      communes: {
        '69264': Ok(
          CommuneStreets(
            commune: villefranche,
            streets: const [],
            skippedStreets: 0,
          ),
        ),
      },
    );
    communes = FakeCommuneSearch(
      answers: {
        'Villef': Ok([
          CommuneMatch(commune: villefranche, postcodes: const ['69400']),
        ]),
      },
    );
    // A ProviderContainer is what a ProviderScope holds, without widgets:
    // the overrides bind the ports to the fakes.
    container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        addressDirectoryProvider.overrideWithValue(directory),
        communeSearchProvider.overrideWithValue(communes),
        clockProvider.overrideWithValue(FakeClock(twoPm)),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
        identityProvider.overrideWithValue(FakeIdentity(lea)),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('ports', () {
    final ports = <String, Provider<Object>>{
      'StreetRepository': streetRepositoryProvider,
      'AddressDirectory': addressDirectoryProvider,
      'CommuneSearch': communeSearchProvider,
      'Clock': clockProvider,
      'IdGenerator': idGeneratorProvider,
      'IdentityProvider': identityProvider,
    };
    ports.forEach((name, port) {
      test('should name $name when nobody bound it', () {
        final empty = ProviderContainer();
        addTearDown(empty.dispose);

        expect(
          () => empty.read(port),
          throwsA(predicate((Object error) => '$error'.contains(name))),
        );
      });
    });
  });

  group('use cases', () {
    test('should observe a street of the bound repository', () async {
      final street = await container.read(observeStreetProvider)(lilasId).first;

      expect(street, same(lilas));
    });

    test('should observe the streets of the bound repository', () async {
      final all = await container.read(observeStreetsProvider)().first;

      expect(all, [same(lilas)]);
    });

    test('should mark a house with the bound clock and member', () async {
      final change = valueOf(
        await container.read(markHouseProvider)(
          lilasId,
          n('7'),
          VisitStatus.done,
        ),
      );

      expect(change.stamp, leaAtTwo);
      expect(streets.saved, hasLength(1));
    });

    test('should set a detail of a house', () async {
      final change = valueOf(
        await container.read(setHouseDetailsProvider)(
          lilasId,
          n('7'),
          NoteMark(note('chat')),
        ),
      );

      expect(change.stamp, leaAtTwo);
    });

    test('should mark a door', () async {
      final change = valueOf(
        await container.read(markDwellingProvider)(
          lilasId,
          n('8'),
          rdc('02'),
          const StatusMark(VisitStatus.done),
        ),
      );

      expect(change.stamp, leaAtTwo);
    });

    test('should describe a building', () async {
      final change = valueOf(
        await container.read(describeBuildingProvider)(
          lilasId,
          n('8'),
          const BackToSingleHouse(),
        ),
      );

      expect(change.stamp, leaAtTwo);
    });

    test('should edit the numbers of a street', () async {
      valueOf(
        await container.read(editStreetNumbersProvider)(
          lilasId,
          const DeleteStreet(),
        ),
      );

      expect(streets[lilasId]!.deletion, leaAtTwo);
    });

    test('should undo a change', () async {
      final change = valueOf(
        await container.read(markHouseProvider)(
          lilasId,
          n('7'),
          VisitStatus.done,
        ),
      );

      valueOf(await container.read(undoLastChangeProvider)(change));

      expect(houseOf(streets[lilasId]!, '7'), seven);
    });

    test('should list the streets of a commune from the directory', () async {
      valueOf(await container.read(listCommuneStreetsProvider)('69264'));

      expect(directory.communesAsked, ['69264']);
    });

    test('should import with the bound directory and ids', () async {
      final report = valueOf(
        await container.read(importReferenceAreaProvider)('69264'),
      );

      expect(report, isA<ImportReport>());
      expect(report.commune, villefranche);
      expect(directory.communesAsked, ['69264']);
      expect(streets[StreetId('street-1')], isNull);
    });

    test('should search communes with the bound service', () async {
      final found = valueOf(
        await container.read(searchCommunesProvider)('Villef'),
      );

      expect(found.single.commune, villefranche);
      expect(communes.searched, ['Villef']);
    });

    test('should find the imported streets in the bound repository', () async {
      final imported = await container.read(findImportedStreetsProvider)([
        lilas.banId!,
      ]);

      expect(imported, {lilas.banId});
    });
  });
}
