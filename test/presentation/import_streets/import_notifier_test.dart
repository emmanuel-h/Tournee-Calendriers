import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_notifier.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_commune_search.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

// Four streets of Villefranche-sur-Saône, as the BAN lists them (not in
// alphabetical order).
final _morin = BanStreetId('69264_1460');
final _bonnet = BanStreetId('69264_0682');
final _bordelan = BanStreetId('69264_0246');
final _square = BanStreetId('69264_1781');

DirectoryStreet _listed(BanStreetId id, String name, int count) =>
    DirectoryStreet(
      id: id,
      name: valueOf(StreetName.create(name)),
      numberCount: count,
    );

final _communeStreets = CommuneStreets(
  commune: villefranche,
  streets: [
    _listed(_morin, 'Rue Pierre Morin', 19),
    _listed(_bonnet, 'Rue des Frères Bonnet', 41),
    _listed(_bordelan, 'Petit Chemin de Bordelan', 12),
    _listed(_square, 'Allée du Square', 0),
  ],
  skippedStreets: 0,
);

StreetNumbers _numbers(BanStreetId id, String name) => StreetNumbers(
  id: id,
  name: valueOf(StreetName.create(name)),
  commune: villefranche,
  numbers: [
    DirectoryNumber(number: n('1')),
    DirectoryNumber(number: n('2')),
  ],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

final _villefranche = CommuneMatch(
  commune: villefranche,
  postcodes: const ['69400'],
);
const _label = 'Villefranche-sur-Saône (69400)';
final _option = CommuneOption.of(_villefranche);

/// Lets every pending future and zero-length timer run.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeCommuneSearch communes;
  late FakeAddressDirectory directory;
  late FakeStreetRepository streets;
  late Map<String, Result<CommuneStreets, AddressDirectoryFailure>> listings;
  late ProviderContainer container;

  ImportNotifier notifier() => container.read(importProvider.notifier);
  ImportState state() => container.read(importProvider);

  setUp(() {
    communes = FakeCommuneSearch(
      answers: {
        'Villef': Ok([_villefranche]),
        'Ville': Ok([_villefranche]),
        'Vill': Ok([_villefranche]),
        'Vi': const Ok([]),
        'Panne': const Err(CommuneSearchFailure.noNetwork),
      },
    );
    // A map the tests may change, to answer differently the second time.
    listings = {'69264': Ok(_communeStreets)};
    directory = FakeAddressDirectory(
      communes: listings,
      streets: {
        _morin: Ok(_numbers(_morin, 'Rue Pierre Morin')),
        _bonnet: Ok(_numbers(_bonnet, 'Rue des Frères Bonnet')),
        _bordelan: Ok(_numbers(_bordelan, 'Petit Chemin de Bordelan')),
        _square: Ok(_numbers(_square, 'Allée du Square')),
      },
    );
    streets = FakeStreetRepository();
    container = ProviderContainer(
      overrides: [
        communeSearchProvider.overrideWithValue(communes),
        addressDirectoryProvider.overrideWithValue(directory),
        streetRepositoryProvider.overrideWithValue(streets),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
        // Zero, so the debounce is a single turn of the event loop.
        communeSearchDelayProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    // Keeps the auto-disposed provider alive, as the screen does.
    container.listen(importProvider, (_, _) {});
  });

  Future<void> chooseVillefranche() async {
    await notifier().chooseCommune(_option, label: _label);
  }

  /// Rue Pierre Morin, imported before and sent to the Corbeille.
  Future<void> morinInCorbeille() => streets.add(
    valueOf(
      Street.create(
        id: StreetId('s'),
        name: 'Rue Pierre Morin',
        commune: villefranche,
        banId: _morin,
      ),
    ).delete(by: lea, at: twoPm).$1,
  );

  test('should wait 300 ms after the last key by default', () {
    final plain = ProviderContainer();
    addTearDown(plain.dispose);

    expect(
      plain.read(communeSearchDelayProvider),
      const Duration(milliseconds: 300),
    );
  });

  group('commune search', () {
    test('should suggest the communes found once the typing pauses', () async {
      final typed = notifier().typeCommune('Villef');

      expect(state().query, 'Villef');
      expect(state().searching, isTrue);
      expect(communes.searched, isEmpty);

      await typed;

      expect(communes.searched, ['Villef']);
      expect(state().searching, isFalse);
      expect((state().suggestions as CommunesFound).communes, [
        CommuneOption(
          name: 'Villefranche-sur-Saône',
          inseeCode: insee('69264'),
          postcodes: const ['69400'],
        ),
      ]);
    });

    test(
      'should suggest nothing without asking when one letter is typed',
      () async {
        await notifier().typeCommune('Villef');

        await notifier().typeCommune(' V ');

        expect(state().query, ' V ');
        expect(state().searching, isFalse);
        expect(state().suggestions, isA<NoSuggestions>());
        expect(communes.searched, ['Villef']);
      },
    );

    test('should search when two letters are typed', () async {
      await notifier().typeCommune('Vi');

      expect(communes.searched, ['Vi']);
      expect((state().suggestions as CommunesFound).communes, isEmpty);
    });

    test('should search only the last text when keys come quickly', () async {
      final first = notifier().typeCommune('Vi');
      final second = notifier().typeCommune('Vill');
      final last = notifier().typeCommune('Ville');
      await Future.wait([first, second, last]);

      expect(communes.searched, ['Ville']);
      expect(state().query, 'Ville');
    });

    test('should ignore an answer that arrives after a newer text', () async {
      communes.hold('Vill');
      final slow = notifier().typeCommune('Vill');
      await _settle();
      expect(communes.searched, ['Vill']);

      await notifier().typeCommune('Panne');
      communes.release('Vill', Ok([_villefranche]));
      await slow;

      expect(state().query, 'Panne');
      expect(
        (state().suggestions as CommuneSearchFailed).failure,
        ImportProblem.noNetwork,
      );
    });

    test('should tell the failure of the search', () async {
      await notifier().typeCommune('Panne');

      expect(state().searching, isFalse);
      expect(
        (state().suggestions as CommuneSearchFailed).failure,
        ImportProblem.noNetwork,
      );
    });

    test(
      'should forget the chosen commune and its streets when typing',
      () async {
        await chooseVillefranche();
        notifier().filter('morin');

        await notifier().typeCommune('Vill');

        expect(state().commune, isNull);
        expect(state().streets, isA<NoCommuneChosen>());
        expect(state().filter, '');
        expect(state().run, isA<ImportNotStarted>());
      },
    );

    test('should not search when the screen left during the pause', () async {
      final typed = notifier().typeCommune('Villef');
      container.dispose();
      await typed;

      expect(communes.searched, isEmpty);
    });

    test('should drop the answer when the screen left meanwhile', () async {
      communes.hold('Vill');
      final typed = notifier().typeCommune('Vill');
      await _settle();
      container.dispose();

      communes.release('Vill', Ok([_villefranche]));

      await expectLater(typed, completes);
    });
  });

  group('choosing a commune', () {
    test('should list its streets in French order, nothing checked', () async {
      final chosen = notifier().chooseCommune(_option, label: _label);

      expect(state().query, _label);
      expect(state().commune, _option);
      expect(state().suggestions, isA<NoSuggestions>());
      expect(state().streets, isA<LoadingStreets>());

      await chosen;

      expect(directory.communesAsked, ['69264']);
      expect((state().streets as StreetsLoaded).streets, [
        StreetChoice(
          id: _square,
          name: 'Allée du Square',
          numberCount: 0,
          alreadyImported: false,
          checked: false,
        ),
        StreetChoice(
          id: _bordelan,
          name: 'Petit Chemin de Bordelan',
          numberCount: 12,
          alreadyImported: false,
          checked: false,
        ),
        StreetChoice(
          id: _bonnet,
          name: 'Rue des Frères Bonnet',
          numberCount: 41,
          alreadyImported: false,
          checked: false,
        ),
        StreetChoice(
          id: _morin,
          name: 'Rue Pierre Morin',
          numberCount: 19,
          alreadyImported: false,
          checked: false,
        ),
      ]);
    });

    test('should order two streets of the same name by BAN id', () async {
      listings['69264'] = Ok(
        CommuneStreets(
          commune: villefranche,
          streets: [
            _listed(_morin, 'Grande Rue', 1),
            _listed(_bonnet, 'Grande rue', 1),
          ],
          skippedStreets: 0,
        ),
      );

      await chooseVillefranche();

      expect(
        (state().streets as StreetsLoaded).streets.map((street) => street.id),
        [_bonnet, _morin],
      );
    });

    test(
      'should show the streets already on the phone ticked and imported',
      () async {
        await streets.add(
          valueOf(
            Street.create(
              id: StreetId('s'),
              name: 'Rue Pierre Morin',
              commune: villefranche,
              banId: _morin,
            ),
          ),
        );

        await chooseVillefranche();

        final morin = (state().streets as StreetsLoaded).streets.last;
        expect(morin.id, _morin);
        expect(morin.alreadyImported, isTrue);
        expect(morin.checked, isTrue);
        expect(state().checkedCount, 0);
      },
    );

    test(
      'should show a street in the Corbeille unticked and free to tick',
      () async {
        await morinInCorbeille();

        await chooseVillefranche();

        final morin = (state().streets as StreetsLoaded).streets.last;
        expect(morin.id, _morin);
        expect(morin.inCorbeille, isTrue);
        expect(morin.alreadyImported, isFalse);
        expect(morin.checked, isFalse);
        expect(morin.selectable, isTrue);
      },
    );

    test('should ignore a pending search when a commune is chosen', () async {
      communes.hold('Vill');
      final typed = notifier().typeCommune('Vill');
      await _settle();

      await chooseVillefranche();
      communes.release('Vill', Ok([_villefranche]));
      await typed;

      expect(state().suggestions, isA<NoSuggestions>());
      expect(state().query, _label);
    });

    test('should tell the failure and list again on « Réessayer »', () async {
      listings['69264'] = const Err(AddressDirectoryFailure.noNetwork);
      await chooseVillefranche();

      expect(
        (state().streets as StreetsFailed).failure,
        ImportProblem.noNetwork,
      );

      listings['69264'] = Ok(_communeStreets);
      await notifier().retryStreets();

      expect((state().streets as StreetsLoaded).streets, hasLength(4));
      expect(directory.communesAsked, ['69264', '69264']);
    });

    test(
      'should ignore the streets when another commune is typed meanwhile',
      () async {
        directory.holdCommune('69264');
        final chosen = chooseVillefranche();
        await _settle();

        await notifier().typeCommune('V');
        directory.releaseCommune('69264');
        await chosen;

        expect(state().streets, isA<NoCommuneChosen>());
      },
    );

    test('should drop the streets when the screen left meanwhile', () async {
      directory.holdCommune('69264');
      final chosen = chooseVillefranche();
      await _settle();
      container.dispose();

      directory.releaseCommune('69264');

      await expectLater(chosen, completes);
    });
  });

  group('checklist', () {
    setUp(chooseVillefranche);

    StreetChoice choice(BanStreetId id) => (state().streets as StreetsLoaded)
        .streets
        .singleWhere((street) => street.id == id);

    test('should tick then untick a street', () {
      notifier().toggle(_morin);
      expect(choice(_morin).checked, isTrue);
      expect(choice(_bonnet).checked, isFalse);
      expect(state().checkedCount, 1);

      notifier().toggle(_morin);
      expect(choice(_morin).checked, isFalse);
      expect(state().checkedCount, 0);
    });

    test('should leave a street already imported as it is', () async {
      await streets.add(
        valueOf(
          Street.create(
            id: StreetId('s'),
            name: 'Rue Pierre Morin',
            commune: villefranche,
            banId: _morin,
          ),
        ),
      );
      await notifier().retryStreets();

      notifier().toggle(_morin);

      expect(choice(_morin).checked, isTrue);
      expect(choice(_morin).alreadyImported, isTrue);
    });

    test('should tick and untick every street the filter shows', () {
      notifier().filter('rue');
      expect(state().filter, 'rue');

      notifier().checkAllVisible(checked: true);

      expect(choice(_morin).checked, isTrue);
      expect(choice(_bonnet).checked, isTrue);
      expect(choice(_bordelan).checked, isFalse);
      expect(choice(_square).checked, isFalse);
      expect(state().allVisibleChecked, isTrue);

      notifier().checkAllVisible(checked: false);

      expect(choice(_morin).checked, isFalse);
      expect(choice(_bonnet).checked, isFalse);
    });

    test('should tick a street in the Corbeille with all the others', () async {
      await morinInCorbeille();
      await notifier().retryStreets();

      notifier().checkAllVisible(checked: true);

      expect(choice(_morin).checked, isTrue);
      expect(state().toImport, contains(_morin));
    });

    test('should change nothing when no street is listed', () async {
      await notifier().typeCommune('Vi');

      notifier().toggle(_morin);
      notifier().checkAllVisible(checked: true);

      expect(state().streets, isA<NoCommuneChosen>());
    });
  });

  group('import', () {
    setUp(chooseVillefranche);

    test('should do nothing when no street is ticked', () async {
      await notifier().import();

      expect(state().run, isA<ImportNotStarted>());
      expect(directory.streetsAsked, isEmpty);
    });

    test('should import the ticked streets and tell the progress', () async {
      final runs = <ImportRun>[];
      container.listen(importProvider, (_, next) => runs.add(next.run));
      notifier()
        ..toggle(_morin)
        ..toggle(_bordelan);

      await notifier().import();

      expect(
        [
          for (final run in runs.whereType<ImportRunning>())
            (run.done, run.total),
        ],
        [(0, 2), (1, 2), (2, 2)],
      );
      expect(directory.streetsAsked, [_morin, _bordelan]);
      expect(streets.added.map((street) => street.banId), [_morin, _bordelan]);
      final summary = (state().run as ImportFinished).summary;
      expect(summary.imported, 2);
      expect(summary.failed, 0);
      expect(summary.failure, isNull);
      expect(summary.complete, isTrue);
    });

    test('should import the ticked streets the filter hides too', () async {
      notifier().toggle(_morin);
      notifier().filter('bordelan');

      await notifier().import();

      expect(directory.streetsAsked, [_morin]);
    });

    test('should show the imported streets as already imported', () async {
      notifier().toggle(_morin);

      await notifier().import();

      final morin = (state().streets as StreetsLoaded).streets.last;
      expect(morin.alreadyImported, isTrue);
      expect(morin.checked, isTrue);
      expect(state().checkedCount, 0);
    });

    test('should keep the failed streets ticked and tell why', () async {
      directory.streets[_bonnet] = const Err(
        AddressDirectoryFailure.serviceError,
      );
      notifier()
        ..toggle(_morin)
        ..toggle(_bonnet);

      await notifier().import();

      final summary = (state().run as ImportFinished).summary;
      expect(summary.imported, 1);
      expect(summary.failed, 1);
      expect(summary.failure, ImportProblem.serviceError);
      expect(summary.complete, isFalse);
      expect(state().toImport, [_bonnet]);
      expect(state().canImport, isTrue);
    });

    test('should tell no network first when several failures happen', () async {
      directory.streets[_bordelan] = const Err(
        AddressDirectoryFailure.serviceError,
      );
      directory.streets[_morin] = const Err(AddressDirectoryFailure.noNetwork);
      notifier()
        ..toggle(_bordelan)
        ..toggle(_morin);

      await notifier().import();

      final summary = (state().run as ImportFinished).summary;
      expect(summary.failed, 2);
      expect(summary.failure, ImportProblem.noNetwork);
    });

    test(
      'should count a street the commune no longer lists as failed',
      () async {
        notifier()
          ..toggle(_morin)
          ..toggle(_square);
        listings['69264'] = Ok(
          CommuneStreets(
            commune: villefranche,
            streets: [_listed(_morin, 'Rue Pierre Morin', 19)],
            skippedStreets: 0,
          ),
        );

        await notifier().import();

        final summary = (state().run as ImportFinished).summary;
        expect(summary.imported, 1);
        expect(summary.failed, 1);
        expect(summary.failure, ImportProblem.notFound);
      },
    );

    test(
      'should count a street found on the phone meanwhile as imported',
      () async {
        notifier().toggle(_morin);
        await streets.add(
          valueOf(
            Street.create(
              id: StreetId('s'),
              name: 'Rue Pierre Morin',
              commune: villefranche,
              banId: _morin,
            ),
          ),
        );

        await notifier().import();

        final summary = (state().run as ImportFinished).summary;
        expect(summary.imported, 1);
        expect(summary.failed, 0);
      },
    );

    test(
      'should bring back a street from the Corbeille without the BAN',
      () async {
        await morinInCorbeille();
        await notifier().retryStreets();
        notifier().toggle(_morin);
        // The network is gone since the streets were listed.
        listings['69264'] = const Err(AddressDirectoryFailure.noNetwork);

        await notifier().import();

        final summary = (state().run as ImportFinished).summary;
        expect(summary.restored, 1);
        expect(summary.imported, 0);
        expect(summary.failed, 0);
        expect(directory.streetsAsked, isEmpty);
        expect(streets[StreetId('s')]!.isDeleted, isFalse);
        final morin = (state().streets as StreetsLoaded).streets.last;
        expect(morin.alreadyImported, isTrue);
        expect(morin.inCorbeille, isFalse);
        expect(morin.checked, isTrue);
      },
    );

    test('should tell the failure when the commune cannot be listed', () async {
      notifier().toggle(_morin);
      listings['69264'] = const Err(AddressDirectoryFailure.noNetwork);

      await notifier().import();

      expect((state().run as ImportFailed).failure, ImportProblem.noNetwork);
    });

    test('should forget the import when another commune is typed', () async {
      notifier().toggle(_morin);
      await notifier().import();

      await notifier().typeCommune('V');

      expect(state().run, isA<ImportNotStarted>());
    });

    test(
      'should finish quietly when the screen left during the import',
      () async {
        notifier().toggle(_morin);
        directory.holdStreet(_morin);
        final importing = notifier().import();
        await _settle();
        container.dispose();

        directory.releaseStreet(_morin);

        await expectLater(importing, completes);
        expect(streets.added.single.banId, _morin);
      },
    );
  });
}
