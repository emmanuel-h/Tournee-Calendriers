import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/team_roster.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart' show n, villefranche;
import 'tournee_fixtures.dart';

/// Rue des Lilas, covered by [assignees].
Street _lilas(Set<MemberId> assignees) => valueOf(
  Street.create(
    id: StreetId('lilas'),
    name: 'Rue des Lilas',
    commune: villefranche,
    assignees: assignees,
    houses: [House(number: n('1'))],
  ),
);

void main() {
  // The team of `team()`: Manu and Léa active, Julie pending; Paul and Sam
  // are not in it.
  group('a known team', () {
    final roster = TeamRoster.of(team(), me: leaId);

    test('should keep the assignees who are in the team', () {
      expect(roster.assigneesOf(_lilas({manuId, leaId})), {manuId, leaId});
    });

    test('should leave out an assignee no longer in the team', () {
      expect(roster.assigneesOf(_lilas({manuId, paulId})), {manuId});
    });

    test('should keep an assignee whose request is pending', () {
      // Still in the tournée: someone who left and asks to join again.
      expect(roster.assigneesOf(_lilas({julieId, paulId})), {julieId});
    });

    test('should keep the member on the phone though not in the team', () {
      // An admin visiting the tournée (PLAN §5.12) is no member of it.
      final visiting = TeamRoster.of(team(), me: samId);

      expect(visiting.assigneesOf(_lilas({samId, paulId})), {samId});
    });

    test('should find the street free when its only assignee left', () {
      expect(roster.isTaken(_lilas({paulId})), isFalse);
    });

    test('should find the street taken while a member covers it', () {
      expect(roster.isTaken(_lilas({paulId, manuId})), isTrue);
    });

    test('should find the street free when nobody covers it', () {
      expect(roster.isTaken(_lilas({})), isFalse);
    });
  });

  group('a team not read yet', () {
    final roster = TeamRoster.of(null, me: leaId);

    test('should trust every assignee', () {
      expect(roster.assigneesOf(_lilas({paulId, julieId})), {paulId, julieId});
      expect(roster.isTaken(_lilas({paulId})), isTrue);
    });

    test('should be the roster that trusts every assignee', () {
      expect(TeamRoster.unknown.assigneesOf(_lilas({paulId, samId})), {
        paulId,
        samId,
      });
      expect(TeamRoster.unknown.isTaken(_lilas({})), isFalse);
    });
  });
}
