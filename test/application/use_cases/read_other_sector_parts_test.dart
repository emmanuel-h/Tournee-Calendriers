import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/read_other_sector_parts.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';

import '../../support/fakes/fake_street_part_index.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _nationale = BanStreetId('69264_0001');

SectorPart _other(int sector, String centre) => SectorPart(
  sector: valueOf(SectorNumber.create(sector)),
  centre: valueOf(RescueCentre.create(centre)),
  part: part(odd: range(19, 41), even: SidePart.none),
);

void main() {
  test(
    'should give the other secteurs\' parts by number, then by centre',
    () async {
      final index = FakeStreetPartIndex({
        _nationale: [
          _other(12, 'CS Villefranche'),
          _other(8, 'CS Villefranche'),
          _other(12, 'CS Arnas'),
        ],
      });

      final others = await ReadOtherSectorParts(index)(_nationale);

      expect(others, [
        _other(8, 'CS Villefranche'),
        _other(12, 'CS Arnas'),
        _other(12, 'CS Villefranche'),
      ]);
      expect(index.asked, [_nationale]);
    },
  );

  test('should give none when no other secteur holds the street', () async {
    final others = await ReadOtherSectorParts(FakeStreetPartIndex())(
      _nationale,
    );

    expect(others, isEmpty);
  });
}
