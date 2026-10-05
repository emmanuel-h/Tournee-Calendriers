import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/find_imported_streets.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

Street _imported(String id, String banId) => valueOf(
  Street.create(
    id: StreetId(id),
    name: 'Rue $id',
    commune: villefranche,
    banId: BanStreetId(banId),
  ),
);

void main() {
  test('should give the BAN ids already on the phone', () async {
    final streets = FakeStreetRepository([_imported('a', '69264_1460')]);

    final imported = await FindImportedStreets(streets)([
      BanStreetId('69264_1460'),
      BanStreetId('69264_0682'),
    ]);

    expect(imported, {BanStreetId('69264_1460'): ImportedStreetState.active});
  });

  test('should tell a street in the Corbeille', () async {
    final (deleted, _) = _imported(
      'a',
      '69264_0246',
    ).delete(by: lea, at: twoPm);
    final streets = FakeStreetRepository([deleted]);

    final imported = await FindImportedStreets(streets)([
      BanStreetId('69264_0246'),
    ]);

    expect(imported, {
      BanStreetId('69264_0246'): ImportedStreetState.inCorbeille,
    });
  });

  test('should give nothing when no street was imported', () async {
    final imported = await FindImportedStreets(FakeStreetRepository())([
      BanStreetId('69264_1460'),
    ]);

    expect(imported, isEmpty);
  });
}
