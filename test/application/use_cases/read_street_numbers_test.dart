import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/read_street_numbers.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _morinId = BanStreetId('69264_1460');

void main() {
  test('should give the numbers the directory lists for the street', () async {
    final numbers = StreetNumbers(
      id: _morinId,
      name: streetName('Rue Pierre Morin'),
      commune: villefranche,
      numbers: [DirectoryNumber(number: n('2'))],
      invalidNumbers: 0,
      duplicateNumbers: 0,
    );
    final directory = FakeAddressDirectory(streets: {_morinId: Ok(numbers)});

    final read = valueOf(await ReadStreetNumbers(directory)(_morinId));

    expect(read, same(numbers));
    expect(directory.streetsAsked, [_morinId]);
  });

  test('should give the failure of the directory', () async {
    final directory = FakeAddressDirectory(
      streets: {_morinId: const Err(AddressDirectoryFailure.noNetwork)},
    );

    expect(
      failureOf(await ReadStreetNumbers(directory)(_morinId)),
      AddressDirectoryFailure.noNetwork,
    );
  });
}
