import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_commune.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

void main() {
  final centre = at(45.9837, 4.726);

  test('should keep the commune and its centre when built', () {
    final commune = TourneeCommune(commune: villefranche, centre: centre);

    expect(commune.commune, villefranche);
    expect(commune.centre, centre);
    expect(commune.inseeCode, insee('69264'));
    expect(commune.name, 'Villefranche-sur-Saône');
  });

  test('should have no centre when none is given', () {
    expect(TourneeCommune(commune: villefranche).centre, isNull);
  });

  test('should be equal when the commune and the centre are equal', () {
    expect(
      TourneeCommune(commune: villefranche, centre: centre),
      TourneeCommune(commune: villefranche, centre: at(45.9837, 4.726)),
    );
    expect(
      TourneeCommune(commune: villefranche, centre: centre).hashCode,
      TourneeCommune(
        commune: villefranche,
        centre: at(45.9837, 4.726),
      ).hashCode,
    );
  });

  test('should differ when the centre differs', () {
    expect(
      TourneeCommune(commune: villefranche, centre: centre),
      isNot(TourneeCommune(commune: villefranche)),
    );
  });

  test('should differ when the commune differs', () {
    final gleize = TourneeCommune(
      commune: valueOf(Commune.create(inseeCode: '69092', name: 'Gleizé')),
      centre: centre,
    );

    expect(
      TourneeCommune(commune: villefranche, centre: centre),
      isNot(gleize),
    );
  });

  test('should show its code, name and centre when printed', () {
    expect(
      TourneeCommune(commune: villefranche, centre: centre).toString(),
      'TourneeCommune(69264, Villefranche-sur-Saône, GeoPoint(45.9837, 4.726))',
    );
  });
}
