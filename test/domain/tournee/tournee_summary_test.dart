import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

import '../../support/results.dart';
import 'my_tournees_fixtures.dart';
import 'tournee_fixtures.dart';

void main() {
  test('should keep what « Mes tournées » shows of a tournée', () {
    final summary = summaryOf('t49', 49, campaign: campaign2027);

    expect(summary.id, TourneeId('t49'));
    expect(summary.number.value, 49);
    expect(summary.centre, csVillefranche);
    expect(summary.campaign, campaign2027);
    expect(summary.status, MemberStatus.active);
  });

  test('should be pending when the request is not accepted yet', () {
    expect(tournee7.isPending, isTrue);
    expect(tournee49.isPending, isFalse);
  });

  test('should be active, all else kept, once the request is accepted', () {
    final accepted = tournee7.accepted();

    expect(accepted.status, MemberStatus.active);
    expect(accepted.id, tournee7.id);
    expect(accepted.number, tournee7.number);
    expect(accepted.centre, tournee7.centre);
    expect(accepted.campaign, tournee7.campaign);
  });

  test('should be equal when every field is', () {
    expect(summaryOf('t49', 49), tournee49);
    expect(summaryOf('t49', 49).hashCode, tournee49.hashCode);
    expect(summaryOf('t49', 49) == summaryOf('t48', 49), isFalse);
    expect(summaryOf('t49', 49) == summaryOf('t49', 48), isFalse);
    expect(
      summaryOf('t49', 49) == summaryOf('t49', 49, campaign: campaign2027),
      isFalse,
    );
    expect(
      summaryOf('t49', 49) ==
          summaryOf('t49', 49, status: MemberStatus.pending),
      isFalse,
    );
    expect(
      tournee49 ==
          TourneeSummary(
            id: tournee49.id,
            number: tournee49.number,
            centre: valueOf(RescueCentre.create('CS Villefranche-sur-Saône')),
            campaign: tournee49.campaign,
            status: tournee49.status,
          ),
      isFalse,
    );
  });

  test('should name its id and number when printed', () {
    expect(tournee49.toString(), 'TourneeSummary(t49, 49, 2026, active)');
  });
}
