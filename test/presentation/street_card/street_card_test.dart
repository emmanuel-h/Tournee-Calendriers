import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';

import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' show n, villefranche;

/// Rue des Lilas, 1 of 3 doors done, covered by [assignees].
Street _lilas(Set<MemberId> assignees) => valueOf(
  Street.create(
    id: StreetId('lilas'),
    name: 'Rue des Lilas',
    commune: villefranche,
    assignees: assignees,
    houses: [
      House(number: n('1'), status: VisitStatus.done),
      House(number: n('2')),
      House(number: n('3')),
    ],
  ),
);

void main() {
  group('a street of the tournée', () {
    test('should show its name, commune and progress', () {
      final card = StreetCardInTournee.of(_lilas({}), me: leaId, team: team());

      expect(card.id, StreetId('lilas'));
      expect(card.name, 'Rue des Lilas');
      expect(card.commune, 'Villefranche-sur-Saône');
      expect(card.done, 1);
      expect(card.total, 3);
    });

    test('should be free when nobody covers it', () {
      final card = StreetCardInTournee.of(_lilas({}), me: leaId, team: team());

      expect(card.coverage, StreetCoverage.free);
      expect(card.coveredBy, isEmpty);
    });

    test('should be mine when the member covers it alone', () {
      final card = StreetCardInTournee.of(
        _lilas({leaId}),
        me: leaId,
        team: team(),
      );

      expect(card.coverage, StreetCoverage.mine);
      expect(card.coveredBy, isEmpty);
    });

    test('should be mine and name the others who cover it too, in the '
        'team\'s order', () {
      final card = StreetCardInTournee.of(
        _lilas({julieId, leaId, manuId}),
        me: leaId,
        team: team(),
      );

      expect(card.coverage, StreetCoverage.mine);
      expect(card.coveredBy, ['Manu', 'Julie']);
    });

    test('should be someone else\'s and name who covers it', () {
      final card = StreetCardInTournee.of(
        _lilas({manuId}),
        me: leaId,
        team: team(),
      );

      expect(card.coverage, StreetCoverage.others);
      expect(card.coveredBy, ['Manu']);
    });

    test('should be free when its only assignee is no longer in the '
        'team', () {
      final card = StreetCardInTournee.of(
        _lilas({paulId}),
        me: leaId,
        team: team(),
      );

      expect(card.coverage, StreetCoverage.free);
      expect(card.coveredBy, isEmpty);
    });

    test('should be someone else\'s and name only who is still in the team '
        'when one assignee left', () {
      final card = StreetCardInTournee.of(
        _lilas({paulId, manuId}),
        me: leaId,
        team: team(),
      );

      expect(card.coverage, StreetCoverage.others);
      expect(card.coveredBy, ['Manu']);
    });

    test('should be mine when a visiting admin covers it, though no member '
        'of the team', () {
      final card = StreetCardInTournee.of(
        _lilas({samId}),
        me: samId,
        team: team(),
      );

      expect(card.coverage, StreetCoverage.mine);
      expect(card.coveredBy, isEmpty);
    });

    test('should trust every assignee while the team cannot be read', () {
      final card = StreetCardInTournee.of(
        _lilas({paulId}),
        me: leaId,
        team: null,
      );

      expect(card.coverage, StreetCoverage.others);
    });

    test('should name nobody while the team cannot be read', () {
      final card = StreetCardInTournee.of(
        _lilas({manuId}),
        me: leaId,
        team: null,
      );

      expect(card.coverage, StreetCoverage.others);
      expect(card.coveredBy, isEmpty);
    });

    test('should equal a card with the same values only', () {
      StreetCardInTournee card({
        String name = 'Rue des Lilas',
        String commune = 'Villefranche-sur-Saône',
        int done = 1,
        int total = 3,
        StreetCoverage coverage = StreetCoverage.mine,
        List<String> coveredBy = const ['Manu'],
      }) => StreetCardInTournee(
        id: StreetId('lilas'),
        name: name,
        commune: commune,
        done: done,
        total: total,
        coverage: coverage,
        coveredBy: coveredBy,
      );

      expect(card(), card());
      expect(card().hashCode, card().hashCode);
      expect(card(), isNot(card(name: 'Rue Pasteur')));
      expect(card(), isNot(card(commune: 'Gleizé')));
      expect(card(), isNot(card(done: 2)));
      expect(card(), isNot(card(total: 4)));
      expect(card(), isNot(card(coverage: StreetCoverage.others)));
      expect(card(), isNot(card(coveredBy: ['Julie'])));
      expect(
        card(),
        isNot(
          StreetCardInTournee(
            id: StreetId('pasteur'),
            name: 'Rue des Lilas',
            commune: 'Villefranche-sur-Saône',
            done: 1,
            total: 3,
            coverage: StreetCoverage.mine,
            coveredBy: const ['Manu'],
          ),
        ),
      );
      expect(card().toString(), contains('Rue des Lilas'));
    });
  });

  test('should tell the other cards apart by their values', () {
    const toAdd = StreetCardToAdd(
      name: 'Rue Pierre Morin',
      commune: 'Villefranche-sur-Saône',
      numberCount: 19,
    );

    expect(const StreetCardLoading(), const StreetCardLoading());
    // Built at run time, not as a constant, so its constructor runs.
    // ignore: prefer_const_constructors
    expect(StreetCardLoading(), const StreetCardLoading());
    expect(toAdd, isNot(const StreetCardLoading()));
    expect(
      const StreetCardLoading().hashCode,
      const StreetCardLoading().hashCode,
    );
    expect(
      const StreetCardFailed(LookUpProblem.noNetwork),
      const StreetCardFailed(LookUpProblem.noNetwork),
    );
    expect(
      const StreetCardFailed(LookUpProblem.noNetwork).hashCode,
      const StreetCardFailed(LookUpProblem.noNetwork).hashCode,
    );
    expect(
      const StreetCardFailed(LookUpProblem.noNetwork),
      isNot(const StreetCardFailed(LookUpProblem.serviceError)),
    );
    expect(
      toAdd,
      const StreetCardToAdd(
        name: 'Rue Pierre Morin',
        commune: 'Villefranche-sur-Saône',
        numberCount: 19,
      ),
    );
    expect(
      toAdd.hashCode,
      const StreetCardToAdd(
        name: 'Rue Pierre Morin',
        commune: 'Villefranche-sur-Saône',
        numberCount: 19,
      ).hashCode,
    );
    expect(toAdd.adding, isFalse);
    expect(toAdd.addFailed, isFalse);
    for (final other in const [
      StreetCardToAdd(
        name: 'Rue Pasteur',
        commune: 'Villefranche-sur-Saône',
        numberCount: 19,
      ),
      StreetCardToAdd(
        name: 'Rue Pierre Morin',
        commune: 'Gleizé',
        numberCount: 19,
      ),
      StreetCardToAdd(
        name: 'Rue Pierre Morin',
        commune: 'Villefranche-sur-Saône',
        numberCount: 18,
      ),
      StreetCardToAdd(
        name: 'Rue Pierre Morin',
        commune: 'Villefranche-sur-Saône',
        numberCount: 19,
        adding: true,
      ),
      StreetCardToAdd(
        name: 'Rue Pierre Morin',
        commune: 'Villefranche-sur-Saône',
        numberCount: 19,
        addFailed: true,
      ),
    ]) {
      expect(toAdd, isNot(other));
    }
  });
}
