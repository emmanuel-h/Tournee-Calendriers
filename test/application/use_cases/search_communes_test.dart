import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/application/use_cases/search_communes.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

import '../../support/fakes/fake_commune_search.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

void main() {
  final found = [
    CommuneMatch(commune: villefranche, postcodes: const ['69400']),
  ];

  test(
    'should give the communes the service finds for the trimmed name',
    () async {
      final search = FakeCommuneSearch(answers: {'Villef': Ok(found)});

      final communes = valueOf(await SearchCommunes(search)('  Villef '));

      expect(communes, found);
      expect(search.searched, ['Villef']);
    },
  );

  test('should search when the name has two characters', () async {
    final search = FakeCommuneSearch(answers: {'Vi': Ok(found)});

    expect(valueOf(await SearchCommunes(search)('Vi')), found);
    expect(search.searched, ['Vi']);
  });

  test(
    'should find nothing without asking when the name is one character',
    () async {
      final search = FakeCommuneSearch(answers: {'V': Ok(found)});

      expect(valueOf(await SearchCommunes(search)(' V ')), isEmpty);
      expect(search.searched, isEmpty);
    },
  );

  test('should count an accented letter as one character', () async {
    // `'É'.length` is 1 too, but the rule counts characters as every
    // length limit of the app does (code points).
    final search = FakeCommuneSearch();

    await SearchCommunes(search)('É');

    expect(search.searched, isEmpty);
  });

  test('should give the failure of the service', () async {
    final search = FakeCommuneSearch(
      answers: {'Villef': const Err(CommuneSearchFailure.noNetwork)},
    );

    expect(
      failureOf(await SearchCommunes(search)('Villef')),
      CommuneSearchFailure.noNetwork,
    );
  });
}
