import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';

import '../../support/street_fixtures.dart';

StreetChoice _choice(
  String id,
  String name, {
  bool alreadyImported = false,
  bool checked = false,
  int numberCount = 19,
}) => StreetChoice(
  id: BanStreetId(id),
  name: name,
  numberCount: numberCount,
  alreadyImported: alreadyImported,
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
      expect(street, isNot(_choice('a', 'A', checked: true)));
    });

    test('should name its fields when printed', () {
      expect(
        '${_choice('69264_1460', 'Rue Pierre Morin')}',
        'StreetChoice(69264_1460, Rue Pierre Morin, 19, '
            'alreadyImported: false, checked: false)',
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
      expect(const ImportState(streets: LoadingStreets()).streetCount, 0);
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
      CommuneOption(
        name: 'Villefranche-sur-Saône',
        inseeCode: '69264',
        postcodes: ['69400'],
      ),
    ]);
    final loaded = StreetsLoaded([_choice('a', 'A')]);

    expect(found.communes.single.inseeCode, '69264');
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
    CommuneOption option([List<String> postcodes = const ['69400']]) =>
        CommuneOption(
          name: 'Villefranche-sur-Saône',
          inseeCode: '69264',
          postcodes: postcodes,
        );

    test('should take the name, code and postcodes of a match', () {
      final made = CommuneOption.of(
        CommuneMatch(commune: villefranche, postcodes: ['69400', '69401']),
      );

      expect(made.name, 'Villefranche-sur-Saône');
      expect(made.inseeCode, '69264');
      expect(made.postcodes, ['69400', '69401']);
    });

    test('should be equal only when every field is equal', () {
      expect(option(), option());
      expect(option().hashCode, option().hashCode);
      expect(option(), isNot(option(['69401'])));
      expect(
        option(),
        isNot(
          CommuneOption(name: 'X', inseeCode: '69264', postcodes: ['69400']),
        ),
      );
      expect(
        option(),
        isNot(
          CommuneOption(
            name: 'Villefranche-sur-Saône',
            inseeCode: '69265',
            postcodes: ['69400'],
          ),
        ),
      );
    });

    test('should name its fields when printed', () {
      expect(
        '${option()}',
        'CommuneOption(69264, Villefranche-sur-Saône, [69400])',
      );
    });
  });
}
