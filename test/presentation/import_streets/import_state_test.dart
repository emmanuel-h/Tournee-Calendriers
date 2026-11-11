import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';
import 'package:tournee_calendriers/presentation/street_part/other_sectors.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

StreetChoice _choice(
  String id,
  String name, {
  bool alreadyImported = false,
  bool inCorbeille = false,
  bool checked = false,
  int numberCount = 19,
}) => StreetChoice(
  id: BanStreetId(id),
  name: name,
  numberCount: numberCount,
  alreadyImported: alreadyImported,
  inCorbeille: inCorbeille,
  checked: checked,
);

ImportState _loaded(List<StreetChoice> streets, {String filter = ''}) =>
    ImportState(streets: StreetsLoaded(streets), filter: filter);

void main() {
  group('StreetChoice', () {
    test('should be selectable unless already imported', () {
      expect(_choice('a', 'A').selectable, isTrue);
      expect(
        _choice('a', 'A', alreadyImported: true, checked: true).selectable,
        isFalse,
      );
    });

    test('should be selectable and imported when ticked in the Corbeille', () {
      final street = _choice('a', 'A', inCorbeille: true, checked: true);

      expect(street.selectable, isTrue);
      expect(street.toImport, isTrue);
    });

    test('should be imported when checked and not imported yet', () {
      expect(_choice('a', 'A', checked: true).toImport, isTrue);
      expect(_choice('a', 'A').toImport, isFalse);
      expect(
        _choice('a', 'A', alreadyImported: true, checked: true).toImport,
        isFalse,
      );
    });

    test('should change only what copyWith is given', () {
      final street = _choice('a', 'Rue A', numberCount: 7);

      expect(
        street.copyWith(checked: true),
        _choice('a', 'Rue A', numberCount: 7, checked: true),
      );
      expect(
        street.copyWith(alreadyImported: true),
        _choice('a', 'Rue A', numberCount: 7, alreadyImported: true),
      );
      expect(
        street.copyWith(inCorbeille: true),
        _choice('a', 'Rue A', numberCount: 7, inCorbeille: true),
      );
      expect(street.copyWith(), street);
    });

    test('should be equal only when every field is equal', () {
      final street = _choice('a', 'A');

      expect(street, _choice('a', 'A'));
      expect(street.hashCode, _choice('a', 'A').hashCode);
      expect(street, isNot(_choice('b', 'A')));
      expect(street, isNot(_choice('a', 'B')));
      expect(street, isNot(_choice('a', 'A', numberCount: 3)));
      expect(street, isNot(_choice('a', 'A', alreadyImported: true)));
      expect(street, isNot(_choice('a', 'A', inCorbeille: true)));
      expect(street, isNot(_choice('a', 'A', checked: true)));
    });

    group('its part (PLAN §5.15)', () {
      final evens = part(odd: SidePart.none, even: SidePart.all);
      final numbers = StreetNumbers(
        id: BanStreetId('a'),
        name: streetName('Rue A'),
        commune: villefranche,
        numbers: [
          DirectoryNumber(number: n('1')),
          DirectoryNumber(number: n('2')),
          DirectoryNumber(number: n('3')),
        ],
        invalidNumbers: 0,
        duplicateNumbers: 0,
      );

      test('should hold the whole street, not being read, by default', () {
        final street = _choice('a', 'Rue A');

        expect(street.part, StreetPart.whole);
        expect(street.keptCount, isNull);
        expect(street.readingPart, isFalse);
      });

      test('should hold a part, counting what it keeps among the numbers '
          'read', () {
        final street = _choice(
          'a',
          'Rue A',
          checked: true,
          numberCount: 7,
        ).copyWith(readingPart: true).withPart(evens, numbers);

        expect(street.part, evens);
        expect(street.keptCount, 1);
        expect(street.numberCount, 3);
        expect(street.checked, isTrue);
        expect(street.readingPart, isTrue);
        expect(street.id, BanStreetId('a'));
        expect(street.name, 'Rue A');
      });

      test('should count nothing kept for the whole street', () {
        final street = _choice(
          'a',
          'Rue A',
          checked: true,
        ).withPart(StreetPart.whole, numbers);

        expect(street.keptCount, isNull);
        expect(street.numberCount, 3);
      });

      test('should keep its part through copyWith', () {
        final street = _choice(
          'a',
          'Rue A',
          checked: true,
        ).withPart(evens, numbers).copyWith(readingPart: true);

        expect(street.part, evens);
        expect(street.keptCount, 1);
        expect(street.readingPart, isTrue);
      });

      test('should lose its part with its tick', () {
        final street = _choice(
          'a',
          'Rue A',
          checked: true,
        ).withPart(evens, numbers).copyWith(readingPart: true).unticked();

        expect(street.checked, isFalse);
        expect(street.part, StreetPart.whole);
        expect(street.keptCount, isNull);
        expect(street.numberCount, 3);
        expect(street.readingPart, isTrue);
      });

      test('should offer a part only when ticked to be added, out of the '
          'Corbeille', () {
        expect(_choice('a', 'A', checked: true).partChoosable, isTrue);
        expect(_choice('a', 'A').partChoosable, isFalse);
        expect(
          _choice('a', 'A', checked: true, inCorbeille: true).partChoosable,
          isFalse,
        );
        expect(
          _choice('a', 'A', checked: true, alreadyImported: true).partChoosable,
          isFalse,
        );
      });

      test('should be equal only when its part is', () {
        final street = _choice('a', 'A', checked: true);
        final parted = street.withPart(evens, numbers);

        expect(parted, street.withPart(evens, numbers));
        expect(parted.hashCode, street.withPart(evens, numbers).hashCode);
        expect(parted, isNot(street.withPart(StreetPart.whole, numbers)));
        expect(street.copyWith(readingPart: true), isNot(street));
      });

      test('should print its part and its reading', () {
        expect(
          '${_choice('a', 'Rue A', checked: true).withPart(evens, numbers).copyWith(readingPart: true)}',
          'StreetChoice(a, Rue A, 3, alreadyImported: false, '
              'inCorbeille: false, checked: true, '
              'StreetPart(odd: none, even: all), kept: 1, reading)',
        );
      });

      test('should give the parts of the streets to import, not held '
          'whole', () {
        final state = _loaded([
          _choice('a', 'A', checked: true).withPart(evens, numbers),
          _choice('b', 'B', checked: true),
          _choice('c', 'C').withPart(evens, numbers),
          _choice(
            'd',
            'D',
            checked: true,
            alreadyImported: true,
          ).withPart(evens, numbers),
        ]);

        expect(state.parts, {BanStreetId('a'): evens});
      });
    });

    group('other secteurs (PLAN §5.15)', () {
      final twelve = [
        OtherSectorLine(
          sector: 12,
          part: part(odd: range(19, 41), even: SidePart.none),
        ),
      ];
      final numbers = StreetNumbers(
        id: BanStreetId('a'),
        name: streetName('Rue A'),
        commune: villefranche,
        numbers: [DirectoryNumber(number: n('2'))],
        invalidNumbers: 0,
        duplicateNumbers: 0,
      );

      test('should know none by default', () {
        expect(_choice('a', 'A').others, isEmpty);
      });

      test('should keep them through a tick, a part, an untick', () {
        final street = _choice('a', 'A').copyWith(others: twelve);

        expect(street.copyWith(checked: true).others, twelve);
        expect(
          street
              .copyWith(checked: true)
              .withPart(StreetPart.whole, numbers)
              .others,
          twelve,
        );
        expect(street.copyWith(checked: true).unticked().others, twelve);
      });

      test('should be equal only when they are, and print them', () {
        final street = _choice('a', 'Rue A').copyWith(others: twelve);

        expect(street, _choice('a', 'Rue A').copyWith(others: [...twelve]));
        expect(
          street.hashCode,
          _choice('a', 'Rue A').copyWith(others: [...twelve]).hashCode,
        );
        expect(street, isNot(_choice('a', 'Rue A')));
        expect(
          '$street',
          'StreetChoice(a, Rue A, 19, alreadyImported: false, '
              'inCorbeille: false, checked: false, others: '
              '[OtherSectorLine(12, null, StreetPart(odd: 19–41, even: none))])',
        );
      });
    });

    test('should name its fields when printed', () {
      expect(
        '${_choice('69264_1460', 'Rue Pierre Morin')}',
        'StreetChoice(69264_1460, Rue Pierre Morin, 19, '
            'alreadyImported: false, inCorbeille: false, checked: false)',
      );
    });
  });

  group('ImportState', () {
    test('should start empty, with no commune and nothing to import', () {
      const state = ImportState();

      expect(state.query, '');
      expect(state.searching, isFalse);
      expect(state.suggestions, isA<NoSuggestions>());
      expect(state.commune, isNull);
      expect(state.streets, isA<NoCommuneChosen>());
      expect(state.filter, '');
      expect(state.run, isA<ImportNotStarted>());
      expect(state.visibleStreets, isEmpty);
      expect(state.streetCount, 0);
      expect(state.checkedCount, 0);
      expect(state.allVisibleChecked, isFalse);
      expect(state.canImport, isFalse);
      expect(state.importing, isFalse);
    });

    test('should have no street while loading or failed', () {
      // Built at run time (not `const`), so coverage sees the constructor.
      // ignore: prefer_const_constructors
      final StreetChoices loading = LoadingStreets();
      expect(ImportState(streets: loading).streetCount, 0);
      expect(
        const ImportState(streets: StreetsFailed(ImportProblem.noNetwork))
            .streetCount,
        0,
      );
    });

    test('should show the streets the filter keeps, ignoring accents', () {
      final state = _loaded([
        _choice('a', "Place de l'Église"),
        _choice('b', 'Rue Pierre Morin'),
      ], filter: 'EGLISE');

      expect(state.visibleStreets.map((street) => street.name), [
        "Place de l'Église",
      ]);
      expect(state.streetCount, 2);
    });

    test('should count and list the checked streets, hidden ones included', () {
      final state = _loaded([
        _choice('a', 'Rue A', checked: true),
        _choice('b', 'Rue B', checked: true),
        _choice('c', 'Rue C'),
        _choice('d', 'Rue D', alreadyImported: true, checked: true),
      ], filter: 'Rue A');

      expect(state.checkedCount, 2);
      expect(state.toImport, [BanStreetId('a'), BanStreetId('b')]);
      expect(state.canImport, isTrue);
    });

    test('should tell when every visible selectable street is checked', () {
      expect(
        _loaded([
          _choice('a', 'Rue A', checked: true),
          _choice('d', 'Rue D', alreadyImported: true, checked: true),
        ]).allVisibleChecked,
        isTrue,
      );
      expect(
        _loaded([_choice('a', 'Rue A', checked: true), _choice('b', 'Rue B')])
            .allVisibleChecked,
        isFalse,
      );
      // An unchecked street the filter hides does not count.
      expect(
        _loaded([
          _choice('a', 'Rue A', checked: true),
          _choice('b', 'Rue B'),
        ], filter: 'Rue A').allVisibleChecked,
        isTrue,
      );
    });

    test('should not tell all checked when nothing can be checked', () {
      expect(
        _loaded([_choice('d', 'Rue D', alreadyImported: true, checked: true)])
            .allVisibleChecked,
        isFalse,
      );
    });

    test('should not allow importing while an import runs', () {
      final state = ImportState(
        streets: StreetsLoaded([_choice('a', 'Rue A', checked: true)]),
        run: const ImportRunning(0, 1),
      );

      expect(state.importing, isTrue);
      expect(state.canImport, isFalse);
    });

    test('should keep, set or clear the commune in copyWith', () {
      final match = CommuneOption.of(
        CommuneMatch(commune: villefranche, postcodes: ['69400']),
      );
      final state = ImportState(commune: match);

      expect(state.copyWith(query: 'x').commune, same(match));
      expect(state.copyWith(commune: () => null).commune, isNull);
      expect(const ImportState().copyWith(commune: () => match).commune, match);
    });

    test('should change each field copyWith is given', () {
      final state = const ImportState().copyWith(
        query: 'Vil',
        searching: true,
        suggestions: const CommuneSearchFailed(ImportProblem.serviceError),
        streets: const LoadingStreets(),
        filter: 'mor',
        run: const ImportFailed(ImportProblem.notFound),
      );

      expect(state.query, 'Vil');
      expect(state.searching, isTrue);
      expect(
        (state.suggestions as CommuneSearchFailed).failure,
        ImportProblem.serviceError,
      );
      expect(state.streets, isA<LoadingStreets>());
      expect(state.filter, 'mor');
      expect((state.run as ImportFailed).failure, ImportProblem.notFound);
    });
  });

  group('ImportSummary', () {
    test('should be complete only when nothing failed', () {
      expect(const ImportSummary(imported: 2, failed: 0).complete, isTrue);
      expect(const ImportSummary(imported: 2, failed: 0).restored, 0);
      expect(
        const ImportSummary(
          imported: 2,
          failed: 1,
          failure: ImportProblem.noNetwork,
        ).complete,
        isFalse,
      );
    });
  });

  test('should keep the communes found and the streets read-only', () {
    final found = CommunesFound([
      CommuneOption(commune: villefranche, postcodes: ['69400']),
    ]);
    final loaded = StreetsLoaded([_choice('a', 'A')]);

    expect(found.communes.single.inseeCode.value, '69264');
    expect(found.communes.clear, throwsUnsupportedError);
    expect(loaded.streets.clear, throwsUnsupportedError);
  });

  group('ImportProblem', () {
    test('should tell each failure of the address base', () {
      expect(
        ImportProblem.ofDirectory(AddressDirectoryFailure.noNetwork),
        ImportProblem.noNetwork,
      );
      expect(
        ImportProblem.ofDirectory(AddressDirectoryFailure.serviceError),
        ImportProblem.serviceError,
      );
      expect(
        ImportProblem.ofDirectory(AddressDirectoryFailure.notFound),
        ImportProblem.notFound,
      );
    });

    test('should tell each failure of the commune search', () {
      expect(
        ImportProblem.ofSearch(CommuneSearchFailure.noNetwork),
        ImportProblem.noNetwork,
      );
      expect(
        ImportProblem.ofSearch(CommuneSearchFailure.serviceError),
        ImportProblem.serviceError,
      );
    });
  });

  group('CommuneOption', () {
    final gleize = valueOf(Commune.create(inseeCode: '69092', name: 'Gleizé'));

    CommuneOption option({
      Commune? commune,
      List<String> postcodes = const ['69400'],
      GeoPoint? centre,
    }) => CommuneOption(
      commune: commune ?? villefranche,
      postcodes: postcodes,
      centre: centre ?? at(45.9837, 4.726),
    );

    test('should take the commune, postcodes and centre of a match', () {
      final made = CommuneOption.of(
        CommuneMatch(
          commune: villefranche,
          postcodes: ['69400', '69401'],
          centre: at(45.9837, 4.726),
        ),
      );

      expect(made.commune, villefranche);
      expect(made.name, 'Villefranche-sur-Saône');
      expect(made.inseeCode.value, '69264');
      expect(made.postcodes, ['69400', '69401']);
      expect(made.centre, at(45.9837, 4.726));
    });

    test('should take the commune and centre of a secteur, no postcode', () {
      final made = CommuneOption.ofSector(
        SectorCommune(commune: gleize, centre: at(45.9915, 4.6883)),
      );

      expect(made.commune, gleize);
      expect(made.postcodes, isEmpty);
      expect(made.centre, at(45.9915, 4.6883));
    });

    test('should give the commune as a secteur keeps it', () {
      expect(
        option().sectorCommune,
        SectorCommune(commune: villefranche, centre: at(45.9837, 4.726)),
      );
    });

    test('should be equal only when every field is equal', () {
      expect(option(), option());
      expect(option().hashCode, option().hashCode);
      expect(option(), isNot(option(postcodes: ['69401'])));
      expect(option(), isNot(option(commune: gleize)));
      expect(option(), isNot(option(centre: at(45.9915, 4.6883))));
    });

    group('other secteurs (PLAN §5.15)', () {
      final twelve = [
        OtherSectorLine(
          sector: 12,
          part: part(odd: range(19, 41), even: SidePart.none),
        ),
      ];
      final numbers = StreetNumbers(
        id: BanStreetId('a'),
        name: streetName('Rue A'),
        commune: villefranche,
        numbers: [DirectoryNumber(number: n('2'))],
        invalidNumbers: 0,
        duplicateNumbers: 0,
      );

      test('should know none by default', () {
        expect(_choice('a', 'A').others, isEmpty);
      });

      test('should keep them through a tick, a part, an untick', () {
        final street = _choice('a', 'A').copyWith(others: twelve);

        expect(street.copyWith(checked: true).others, twelve);
        expect(
          street
              .copyWith(checked: true)
              .withPart(StreetPart.whole, numbers)
              .others,
          twelve,
        );
        expect(street.copyWith(checked: true).unticked().others, twelve);
      });

      test('should be equal only when they are, and print them', () {
        final street = _choice('a', 'Rue A').copyWith(others: twelve);

        expect(street, _choice('a', 'Rue A').copyWith(others: [...twelve]));
        expect(
          street.hashCode,
          _choice('a', 'Rue A').copyWith(others: [...twelve]).hashCode,
        );
        expect(street, isNot(_choice('a', 'Rue A')));
        expect(
          '$street',
          'StreetChoice(a, Rue A, 19, alreadyImported: false, '
              'inCorbeille: false, checked: false, others: '
              '[OtherSectorLine(12, null, StreetPart(odd: 19–41, even: none))])',
        );
      });
    });

    test('should name its fields when printed', () {
      expect(
        '${option()}',
        'CommuneOption(69264, Villefranche-sur-Saône, [69400])',
      );
    });
  });
}
