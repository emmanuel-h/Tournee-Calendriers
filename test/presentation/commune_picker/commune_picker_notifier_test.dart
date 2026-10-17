import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/presentation/commune_picker/commune_picker_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_notifier.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';

import '../../support/fakes/fake_commune_search.dart';
import '../../support/geo_fixtures.dart';
import '../../support/street_fixtures.dart';

final _villefranche = CommuneMatch(
  commune: villefranche,
  postcodes: const ['69400'],
  centre: at(45.9837, 4.726),
);

/// Lets every pending future and zero-length timer run.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeCommuneSearch communes;
  late ProviderContainer container;

  CommunePickerNotifier picker() =>
      container.read(communePickerProvider.notifier);
  CommunePickerState state() => container.read(communePickerProvider);

  setUp(() {
    communes = FakeCommuneSearch(
      answers: {
        'Villef': Ok([_villefranche]),
        'Panne': const Err(CommuneSearchFailure.noNetwork),
      },
    );
    container = ProviderContainer(
      overrides: [
        communeSearchProvider.overrideWithValue(communes),
        communeSearchDelayProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    container.listen(communePickerProvider, (_, _) {});
  });

  test('should start empty', () {
    expect(state().query, '');
    expect(state().searching, isFalse);
    expect(state().suggestions, isA<NoSuggestions>());
  });

  test('should suggest the communes found once the typing pauses', () async {
    final typed = picker().type('Villef');

    expect(state().query, 'Villef');
    expect(state().searching, isTrue);
    expect(communes.searched, isEmpty);
    await typed;

    expect(communes.searched, ['Villef']);
    expect(state().query, 'Villef');
    expect(state().searching, isFalse);
    expect((state().suggestions as CommunesFound).communes, [
      CommuneOption.of(_villefranche),
    ]);
  });

  test('should keep the last suggestions while the next search runs', () async {
    await picker().type('Villef');

    final typed = picker().type('Villefr');

    expect(state().suggestions, isA<CommunesFound>());
    await typed;
  });

  test('should ask nothing for one character', () async {
    await picker().type('Villef');

    await picker().type(' V ');

    expect(state().query, ' V ');
    expect(state().searching, isFalse);
    expect(state().suggestions, isA<NoSuggestions>());
    expect(communes.searched, ['Villef']);
  });

  test('should ask for two characters', () async {
    await picker().type('Vi');

    expect(communes.searched, ['Vi']);
  });

  test('should tell why the search failed', () async {
    await picker().type('Panne');

    expect(
      (state().suggestions as CommuneSearchFailed).failure,
      ImportProblem.noNetwork,
    );
  });

  test('should search only the last text typed during the pause', () async {
    final first = picker().type('Vill');
    final second = picker().type('Villef');
    await Future.wait([first, second]);

    expect(communes.searched, ['Villef']);
  });

  test('should ignore a late answer to older text', () async {
    communes.hold('Vill');
    final first = picker().type('Vill');
    await _settle();
    await picker().type('Villef');

    communes.release('Vill', const Ok([]));
    await first;

    expect(state().query, 'Villef');
    expect((state().suggestions as CommunesFound).communes, hasLength(1));
  });

  test('should empty the field and forget a search on its way when '
      'cleared', () async {
    communes.hold('Villef');
    final typed = picker().type('Villef');
    await _settle();

    picker().clear();
    communes.release('Villef', Ok([_villefranche]));
    await typed;

    expect(state().query, '');
    expect(state().searching, isFalse);
    expect(state().suggestions, isA<NoSuggestions>());
  });

  test('should drop an answer arriving after the screen left', () async {
    communes.hold('Villef');
    final typed = picker().type('Villef');
    await _settle();

    container.dispose();
    communes.release('Villef', Ok([_villefranche]));
    await typed;
  });

  test('should drop the search when the screen left during the pause', () {
    final typed = picker().type('Villef');
    container.dispose();

    expect(typed, completes);
  });
}
