import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';

import '../../support/geo_fixtures.dart';
import '../../support/street_fixtures.dart';

void main() {
  CommuneMatch match([List<String> postcodes = const ['69400']]) =>
      CommuneMatch(commune: villefranche, postcodes: postcodes);

  test('should keep its commune and postcodes', () {
    final made = match(['69400', '69401']);

    expect(made.commune, villefranche);
    expect(made.postcodes, ['69400', '69401']);
  });

  test('should copy the postcodes and keep them read-only', () {
    final postcodes = ['69400'];
    final made = match(postcodes);
    postcodes.add('69401');

    expect(made.postcodes, ['69400']);
    expect(() => made.postcodes.add('69401'), throwsUnsupportedError);
  });

  test('should be equal when the commune and postcodes are equal', () {
    expect(match(), match());
    expect(match().hashCode, match().hashCode);
  });

  test('should keep the centre given', () {
    final made = CommuneMatch(
      commune: villefranche,
      postcodes: const ['69400'],
      centre: at(45.9837, 4.726),
    );

    expect(made.centre, at(45.9837, 4.726));
  });

  test('should have no centre when none is given', () {
    expect(match().centre, isNull);
  });

  test('should differ when the centre differs', () {
    final centred = CommuneMatch(
      commune: villefranche,
      postcodes: const ['69400'],
      centre: at(45.9837, 4.726),
    );

    expect(centred, isNot(match()));
  });

  test('should differ when the postcodes differ', () {
    expect(match(), isNot(match(['69401'])));
    expect(match(), isNot(match(['69400', '69401'])));
  });

  test('should name the commune and postcodes when printed', () {
    expect('${match()}', 'CommuneMatch(Villefranche-sur-Saône, [69400])');
  });
}
