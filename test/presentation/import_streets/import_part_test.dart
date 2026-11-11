// The part of each street ticked on « Liste » (PLAN §5.15 « When
// adding »): « Toute la rue › » reads the street's numbers and opens
// « Partie de la rue », the part goes with the tick, and « Ajouter N rues »
// stores only its numbers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/add_streets/part_opening.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_notifier.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart'
    show sectorId, team, villefrancheCommune;
import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _morin = BanStreetId('69264_1460');
final _pasteur = BanStreetId('69264_1200');

/// Rue Pierre Morin: 1 to 4, the 1 with an entrance.
final _morinNumbers = StreetNumbers(
  id: _morin,
  name: streetName('Rue Pierre Morin'),
  commune: villefranche,
  numbers: [
    DirectoryNumber(number: n('1'), position: townHallDoor),
    DirectoryNumber(number: n('2')),
    DirectoryNumber(number: n('3')),
    DirectoryNumber(number: n('4')),
  ],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

final _pasteurNumbers = StreetNumbers(
  id: _pasteur,
  name: streetName('Rue Pasteur'),
  commune: villefranche,
  numbers: [DirectoryNumber(number: n('5'))],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

/// The odd numbers only: the 1 and the 3 of the four.
final _odds = part(odd: SidePart.all, even: SidePart.none);

void main() {
  late FakeAddressDirectory directory;
  late FakeStreetRepository streets;
  late ProviderContainer container;

  ImportNotifier notifier() => container.read(importProvider.notifier);
  ImportState state() => container.read(importProvider);
  StreetChoice choice(BanStreetId id) => (state().streets as StreetsLoaded)
      .streets
      .singleWhere((street) => street.id == id);

  /// The request of [opening], which must be one.
  StreetPartChoice choiceOf(PartOpening opening) =>
      (opening as PartToChoose).request.choice;

  Future<void> open() async {
    container = ProviderContainer(
      overrides: [
        addressDirectoryProvider.overrideWithValue(directory),
        streetRepositoryProvider.overrideWithValue(streets),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
        mySectorsStoreProvider.overrideWithValue(
          FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(sectorId)),
          ),
        ),
        // The 49 has Villefranche-sur-Saône: its streets are listed at
        // once.
        sectorRepositoryProvider.overrideWithValue(
          FakeSectorRepository([
            team(communes: [villefrancheCommune]),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(importProvider, (_, _) {});
    await pumpEventQueue();
  }

  setUp(() async {
    directory = FakeAddressDirectory(
      communes: {
        '69264': Ok(
          CommuneStreets(
            commune: villefranche,
            streets: [
              DirectoryStreet(
                id: _morin,
                name: streetName('Rue Pierre Morin'),
                numberCount: 5,
              ),
              DirectoryStreet(
                id: _pasteur,
                name: streetName('Rue Pasteur'),
                numberCount: 1,
              ),
            ],
            skippedStreets: 0,
          ),
        ),
      },
      streets: {_morin: Ok(_morinNumbers), _pasteur: Ok(_pasteurNumbers)},
    );
    streets = FakeStreetRepository();
    await open();
  });

  test('should read the numbers of a street ticked and open « Partie de la '
      'rue » on them, the row waiting meanwhile', () async {
    notifier().toggle(_morin);
    directory.holdStreet(_morin);

    final opening = notifier().openPart(_morin);
    await pumpEventQueue();

    expect(choice(_morin).readingPart, isTrue);
    directory.releaseStreet(_morin);
    final request = (await opening as PartToChoose).request;
    expect(request.streetName, 'Rue Pierre Morin');
    expect(request.choice.numbers, [
      PartNumber(n('1'), position: townHallDoor),
      PartNumber(n('2')),
      PartNumber(n('3')),
      PartNumber(n('4')),
    ]);
    expect(request.choice.road, StreetShape.none);
    expect(request.choice.part, StreetPart.whole);
    expect(choice(_morin).readingPart, isFalse);
    expect(directory.streetsAsked, [_morin]);
  });

  test('should show the part chosen and how many numbers it keeps', () async {
    notifier().toggle(_morin);
    await notifier().openPart(_morin);

    notifier().choosePart(_morin, _odds);

    expect(
      choice(_morin),
      StreetChoice(
        id: _morin,
        name: 'Rue Pierre Morin',
        numberCount: 4,
        alreadyImported: false,
        checked: true,
        part: _odds,
        keptCount: 2,
      ),
    );
  });

  test('should open again on the part chosen, without reading the numbers '
      'again', () async {
    notifier().toggle(_morin);
    await notifier().openPart(_morin);
    notifier().choosePart(_morin, _odds);

    final opening = await notifier().openPart(_morin);

    expect(choiceOf(opening).part, _odds);
    expect(directory.streetsAsked, [_morin]);
  });

  test('should add only the numbers of the part, with the part, the others '
      'whole', () async {
    notifier()
      ..toggle(_morin)
      ..toggle(_pasteur);
    await notifier().openPart(_morin);
    notifier().choosePart(_morin, _odds);

    await notifier().import();

    final morin = streets.added.first;
    expect(morin.banId, _morin);
    expect(morin.part, _odds);
    expect(morin.houses, [
      House(number: n('1'), position: townHallDoor),
      House(number: n('3')),
    ]);
    expect(streets.added.last.part, StreetPart.whole);
  });

  test('should drop the part with the tick', () async {
    notifier().toggle(_morin);
    await notifier().openPart(_morin);
    notifier()
      ..choosePart(_morin, _odds)
      ..toggle(_morin)
      ..toggle(_morin);

    expect(choice(_morin).checked, isTrue);
    expect(choice(_morin).part, StreetPart.whole);
  });

  test('should drop the parts with « Tout décocher », and keep them with '
      '« Tout cocher »', () async {
    notifier().toggle(_morin);
    await notifier().openPart(_morin);
    notifier()
      ..choosePart(_morin, _odds)
      ..checkAllVisible(checked: true);
    expect(choice(_morin).part, _odds);

    notifier().checkAllVisible(checked: false);

    expect(choice(_morin).part, StreetPart.whole);
  });

  test('should open nothing for a street not ticked', () async {
    expect(await notifier().openPart(_morin), const PartNotOpened());
    expect(directory.streetsAsked, isEmpty);
  });

  test('should open nothing for a street the list does not have', () async {
    expect(
      await notifier().openPart(BanStreetId('69264_9999')),
      const PartNotOpened(),
    );
  });

  test('should open nothing for a street of the Corbeille', () async {
    final (deleted, _) = valueOf(
      Street.create(
        id: StreetId('s'),
        name: 'Rue Pierre Morin',
        commune: villefranche,
        banId: _morin,
      ),
    ).delete(by: lea, at: twoPm);
    await streets.add(deleted);
    await notifier().retryStreets();
    notifier().toggle(_morin);

    expect(await notifier().openPart(_morin), const PartNotOpened());
    expect(directory.streetsAsked, isEmpty);
  });

  test('should open nothing while no commune is chosen', () async {
    // Too short to search: the field is cleared of its commune.
    await notifier().typeCommune('V');

    expect(await notifier().openPart(_morin), const PartNotOpened());
  });

  test('should open nothing once the screen is closed', () async {
    notifier().toggle(_morin);
    directory.holdStreet(_morin);
    final opening = notifier().openPart(_morin);
    await pumpEventQueue();

    container.dispose();
    directory.releaseStreet(_morin);

    expect(await opening, const PartNotOpened());
  });

  test('should not open twice while the numbers are read', () async {
    notifier().toggle(_morin);
    directory.holdStreet(_morin);

    final first = notifier().openPart(_morin);
    final second = await notifier().openPart(_morin);
    directory.releaseStreet(_morin);
    await first;

    expect(second, const PartNotOpened());
    expect(directory.streetsAsked, [_morin]);
  });

  test('should open nothing once unticked while the numbers were '
      'read', () async {
    notifier().toggle(_morin);
    directory.holdStreet(_morin);

    final opening = notifier().openPart(_morin);
    notifier().toggle(_morin);
    directory.releaseStreet(_morin);

    expect(await opening, const PartNotOpened());
    expect(choice(_morin).readingPart, isFalse);
  });

  test('should say offline when the numbers cannot be read', () async {
    directory.streets[_morin] = const Err(AddressDirectoryFailure.noNetwork);
    notifier().toggle(_morin);

    final opening = await notifier().openPart(_morin);

    expect(opening, const PartUnreadable(PartReadProblem.noNetwork));
    expect(choice(_morin).readingPart, isFalse);
  });

  test('should say the service failed when the BAN answers with an error or '
      'no longer knows the street', () async {
    notifier().toggle(_morin);
    directory.streets[_morin] = const Err(AddressDirectoryFailure.serviceError);
    final failed = await notifier().openPart(_morin);
    directory.streets[_morin] = const Err(AddressDirectoryFailure.notFound);
    final unknown = await notifier().openPart(_morin);

    expect(failed, const PartUnreadable(PartReadProblem.unavailable));
    expect(unknown, const PartUnreadable(PartReadProblem.unavailable));
  });

  test('should change nothing for a part of a street not read', () async {
    notifier()
      ..toggle(_morin)
      ..choosePart(_morin, _odds);

    expect(choice(_morin).part, StreetPart.whole);
  });

  test('should change nothing for a part of a street unticked since', () async {
    notifier().toggle(_morin);
    await notifier().openPart(_morin);
    notifier()
      ..toggle(_morin)
      ..choosePart(_morin, _odds);

    expect(choice(_morin).part, StreetPart.whole);
  });

  test('should neither open nor change a part while the streets are '
      'added', () async {
    notifier().toggle(_morin);
    await notifier().openPart(_morin);
    directory.holdStreet(_morin);
    final importing = notifier().import();
    await pumpEventQueue();

    expect(await notifier().openPart(_morin), const PartNotOpened());
    notifier().choosePart(_morin, _odds);
    directory.releaseStreet(_morin);
    await importing;

    expect(streets.added.single.part, StreetPart.whole);
  });
}
