import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/list_commune_streets.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

void main() {
  test('should give the streets the directory lists', () async {
    final listed = CommuneStreets(
      commune: villefranche,
      streets: const [],
      skippedStreets: 2,
    );
    final directory = FakeAddressDirectory(communes: {'69264': Ok(listed)});

    final streets = valueOf(await ListCommuneStreets(directory)('69264'));

    expect(streets, same(listed));
    expect(directory.communesAsked, ['69264']);
  });

  test('should give the failure of the directory', () async {
    final directory = FakeAddressDirectory(
      communes: {'69264': const Err(AddressDirectoryFailure.noNetwork)},
    );

    expect(
      failureOf(await ListCommuneStreets(directory)('69264')),
      AddressDirectoryFailure.noNetwork,
    );
  });
}
