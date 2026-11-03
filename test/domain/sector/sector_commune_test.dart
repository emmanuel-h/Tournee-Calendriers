import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

void main() {
  final centre = at(45.9837, 4.726);

  test('should keep the commune and its centre when built', () {
    final commune = SectorCommune(commune: villefranche, centre: centre);

    expect(commune.commune, villefranche);
    expect(commune.centre, centre);
    expect(commune.inseeCode, insee('69264'));
    expect(commune.name, 'Villefranche-sur-Saône');
  });

  test('should have no centre when none is given', () {
    expect(SectorCommune(commune: villefranche).centre, isNull);
  });

  test('should be equal when the commune and the centre are equal', () {
    expect(
      SectorCommune(commune: villefranche, centre: centre),
      SectorCommune(commune: villefranche, centre: at(45.9837, 4.726)),
    );
    expect(
      SectorCommune(commune: villefranche, centre: centre).hashCode,
      SectorCommune(commune: villefranche, centre: at(45.9837, 4.726)).hashCode,
    );
  });

  test('should differ when the centre differs', () {
    expect(
      SectorCommune(commune: villefranche, centre: centre),
      isNot(SectorCommune(commune: villefranche)),
    );
  });

  test('should differ when the commune differs', () {
    final gleize = SectorCommune(
      commune: valueOf(Commune.create(inseeCode: '69092', name: 'Gleizé')),
      centre: centre,
    );

    expect(SectorCommune(commune: villefranche, centre: centre), isNot(gleize));
  });

  test('should show its code, name and centre when printed', () {
    expect(
      SectorCommune(commune: villefranche, centre: centre).toString(),
      'SectorCommune(69264, Villefranche-sur-Saône, GeoPoint(45.9837, 4.726))',
    );
  });
}
