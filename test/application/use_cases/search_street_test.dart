// The search box of « Ajouter des rues » (PLAN §5.4): a street found by
// name in every commune of the tournée.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/search_street.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

// A made-up second commune: tests name no real place but Villefranche.
final _otherCommune = valueOf(
  Commune.create(inseeCode: '69999', name: 'Autre-Commune'),
);

StreetMatch _match(String id, String name, Commune commune) => StreetMatch(
  id: BanStreetId(id),
  name: streetName(name),
  commune: commune,
  position: at(45.98800, 4.72500),
);

final _morin = _match('69264_1460', 'Rue Pierre Morin', villefranche);
final _pierre = _match('69264_1461', 'Place Pierre Sémard', villefranche);
final _otherPierre = _match('69999_0001', 'Rue Pierre', _otherCommune);

/// A directory that answers each commune with [answers], whatever the
/// text.
FakeAddressDirectory _perCommune(
  Map<String, Result<List<StreetMatch>, AddressDirectoryFailure>> answers,
) => FakeAddressDirectory(searchesByCommune: answers);

void main() {
  test('should search each commune of the tournée, in order', () async {
    final directory = _perCommune({
      '69264': Ok([_morin, _pierre]),
      '69999': Ok([_otherPierre]),
    });

    final found = valueOf(
      await SearchStreet(directory)(
        'pierre',
        communes: [insee('69264'), insee('69999')],
      ),
    );

    expect(found, [_morin, _pierre, _otherPierre]);
    expect(directory.searchesAsked, [('pierre', '69264'), ('pierre', '69999')]);
  });

  test('should search the one commune of the tournée', () async {
    final directory = _perCommune({
      '69264': Ok([_morin]),
    });

    final found = valueOf(
      await SearchStreet(directory)('morin', communes: [insee('69264')]),
    );

    expect(found, [_morin]);
  });

  test('should list a street once when two communes give it', () async {
    final directory = _perCommune({
      '69264': Ok([_morin]),
      '69999': Ok([_morin, _otherPierre]),
    });

    final found = valueOf(
      await SearchStreet(directory)(
        'pierre',
        communes: [insee('69264'), insee('69999')],
      ),
    );

    expect(found, [_morin, _otherPierre]);
  });

  test('should find nothing, without asking, with no commune', () async {
    final directory = _perCommune({});

    final found = valueOf(
      await SearchStreet(directory)('pierre', communes: const []),
    );

    expect(found, isEmpty);
    expect(directory.searchesAsked, isEmpty);
  });

  test('should say the network is missing when offline, and stop', () async {
    final directory = _perCommune({
      '69264': const Err(AddressDirectoryFailure.noNetwork),
      '69999': Ok([_otherPierre]),
    });

    final failure = failureOf(
      await SearchStreet(directory)(
        'pierre',
        communes: [insee('69264'), insee('69999')],
      ),
    );

    expect(failure, AddressDirectoryFailure.noNetwork);
    expect(directory.searchesAsked, [('pierre', '69264')]);
  });

  test('should pass on a failure of a later commune', () async {
    final directory = _perCommune({
      '69264': Ok([_morin]),
      '69999': const Err(AddressDirectoryFailure.serviceError),
    });

    final failure = failureOf(
      await SearchStreet(directory)(
        'pierre',
        communes: [insee('69264'), insee('69999')],
      ),
    );

    expect(failure, AddressDirectoryFailure.serviceError);
  });
}
