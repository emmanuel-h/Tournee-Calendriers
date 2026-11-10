import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart' show lea, n, twoPm, villefranche;

/// Rue des Lilas, 1 of 3 doors done.
final _lilas = valueOf(
  Street.create(
    id: StreetId('lilas'),
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('1'), status: VisitStatus.done),
      House(number: n('2')),
      House(number: n('3')),
    ],
  ),
);

void main() {
  group('a street of the secteur', () {
    test('should show its name, commune and progress', () {
      final card = StreetCardInSector.of(_lilas);

      expect(card.id, StreetId('lilas'));
      expect(card.name, 'Rue des Lilas');
      expect(card.commune, 'Villefranche-sur-Saône');
      expect(card.done, 1);
      expect(card.total, 3);
    });

    test('should count a refused house as visited in its progress', () {
      final (refusing, _) = valueOf(
        _lilas.markHouse(n('2'), VisitStatus.refused, by: lea, at: twoPm),
      );

      final card = StreetCardInSector.of(refusing);

      expect(card.done, 2);
      expect(card.total, 3);
    });

    test('should equal a card with the same values only', () {
      StreetCardInSector card({
        String id = 'lilas',
        String name = 'Rue des Lilas',
        String commune = 'Villefranche-sur-Saône',
        int done = 1,
        int total = 3,
      }) => StreetCardInSector(
        id: StreetId(id),
        name: name,
        commune: commune,
        done: done,
        total: total,
      );

      expect(card(), card());
      expect(card().hashCode, card().hashCode);
      expect(card(), isNot(card(id: 'pasteur')));
      expect(card(), isNot(card(name: 'Rue Pasteur')));
      expect(card(), isNot(card(commune: 'Gleizé')));
      expect(card(), isNot(card(done: 2)));
      expect(card(), isNot(card(total: 4)));
      expect(
        card().toString(),
        'StreetCardInSector(lilas, Rue des Lilas, Villefranche-sur-Saône, 1/3)',
      );
    });
  });
}
