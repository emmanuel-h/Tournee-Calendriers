import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/presentation/street_part/other_sectors.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _csVillefranche = valueOf(RescueCentre.create('CS Villefranche'));
final _cisVillefranche = valueOf(RescueCentre.create('CIS Villefranche'));
final _csArnas = valueOf(RescueCentre.create('CS Arnas'));
final _oddFrom19 = part(odd: range(19, 41), even: SidePart.none);

SectorPart _other(int sector, RescueCentre centre) => SectorPart(
  sector: valueOf(SectorNumber.create(sector)),
  centre: centre,
  part: _oddFrom19,
);

void main() {
  group('centreToSay', () {
    test('should say nothing of the open secteur\'s station, however '
        'written', () {
      expect(centreToSay(_csVillefranche, _csVillefranche), isNull);
      expect(centreToSay(_cisVillefranche, _csVillefranche), isNull);
    });

    test('should name another station', () {
      expect(centreToSay(_csArnas, _csVillefranche), 'CS Arnas');
    });

    test('should name every station when no secteur is open', () {
      expect(centreToSay(_csVillefranche, null), 'CS Villefranche');
    });
  });

  group('OtherSectorLine', () {
    test('should give a line per other secteur, its centre when not ours', () {
      expect(
        OtherSectorLine.of([
          _other(12, _csVillefranche),
          _other(3, _csArnas),
        ], _csVillefranche),
        [
          OtherSectorLine(sector: 12, part: _oddFrom19),
          OtherSectorLine(sector: 3, centre: 'CS Arnas', part: _oddFrom19),
        ],
      );
    });

    test('should compare by value', () {
      final line = OtherSectorLine(sector: 12, part: _oddFrom19);

      expect(
        line.hashCode,
        OtherSectorLine(sector: 12, part: _oddFrom19).hashCode,
      );
      expect(line, isNot(OtherSectorLine(sector: 13, part: _oddFrom19)));
      expect(
        line,
        isNot(
          OtherSectorLine(sector: 12, centre: 'CS Arnas', part: _oddFrom19),
        ),
      );
      expect(
        line,
        isNot(const OtherSectorLine(sector: 12, part: StreetPart.whole)),
      );
      expect(
        line.toString(),
        'OtherSectorLine(12, null, StreetPart(odd: 19–41, even: none))',
      );
    });
  });

  group('OverlapLine', () {
    test('should give a line per overlap, its numbers by label', () {
      expect(
        OverlapLine.of([
          PartOverlap(
            other: _other(3, _csArnas),
            numbers: [n('19'), n('21bis')],
          ),
        ], _csVillefranche),
        [
          OverlapLine(sector: 3, centre: 'CS Arnas', numbers: ['19', '21bis']),
        ],
      );
    });

    test('should compare by value', () {
      final line = OverlapLine(sector: 12, numbers: ['19', '21']);

      expect(line, OverlapLine(sector: 12, numbers: ['19', '21']));
      expect(
        line.hashCode,
        OverlapLine(sector: 12, numbers: ['19', '21']).hashCode,
      );
      expect(line, isNot(OverlapLine(sector: 13, numbers: ['19', '21'])));
      expect(
        line,
        isNot(
          OverlapLine(sector: 12, centre: 'CS Arnas', numbers: ['19', '21']),
        ),
      );
      expect(line, isNot(OverlapLine(sector: 12, numbers: ['19'])));
      expect(line.toString(), 'OverlapLine(12, null, [19, 21])');
    });
  });
}
