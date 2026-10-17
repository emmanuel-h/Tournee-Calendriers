import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';

import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/results.dart';

void main() {
  JoinPreview preview({
    String code = 'K7P2QX',
    String id = 't49',
    int number = 49,
    String centre = 'CS Villefranche',
    int campaign = 2026,
  }) => JoinPreview(
    code: codeOf(code),
    tourneeId: TourneeId(id),
    number: valueOf(TourneeNumber.create(number)),
    centre: valueOf(RescueCentre.create(centre)),
    campaign: valueOf(CampaignYear.create(campaign)),
  );

  test('should keep what the join screen shows', () {
    final made = preview();

    expect(made.code, firstCode);
    expect(made.tourneeId, tourneeId);
    expect(made.number, number49);
    expect(made.centre, csVillefranche);
    expect(made.campaign, campaign2026);
  });

  test('should be equal when every field is equal', () {
    expect(preview(), preview());
    expect(preview().hashCode, preview().hashCode);
  });

  test('should differ when any field differs', () {
    expect(preview(), isNot(preview(code: '234567')));
    expect(preview(), isNot(preview(id: 't50')));
    expect(preview(), isNot(preview(number: 50)));
    expect(preview(), isNot(preview(centre: 'CIS Villefranche')));
    expect(preview(), isNot(preview(campaign: 2027)));
  });

  test('should name the tournée when printed', () {
    expect(
      '${preview()}',
      'JoinPreview(K7P-2QX, t49, 49, CS Villefranche, 2026)',
    );
  });

  group('TourneeOverview', () {
    TourneeOverview overview({
      String id = 't12',
      int number = 12,
      String centre = 'CS Villefranche',
      int campaign = 2026,
      int members = 3,
      int requests = 1,
      bool callerIsActive = true,
    }) => TourneeOverview(
      id: TourneeId(id),
      number: valueOf(TourneeNumber.create(number)),
      centre: valueOf(RescueCentre.create(centre)),
      campaign: valueOf(CampaignYear.create(campaign)),
      activeMembers: members,
      pendingRequests: requests,
      callerIsActive: callerIsActive,
    );

    test('should keep what « Toutes les tournées » shows of a tournée', () {
      final made = overview();

      expect(made.id, TourneeId('t12'));
      expect(made.number.value, 12);
      expect(made.centre, csVillefranche);
      expect(made.campaign, campaign2026);
      expect(made.activeMembers, 3);
      expect(made.pendingRequests, 1);
      expect(made.callerIsActive, isTrue);
    });

    test('should be equal when every field is equal', () {
      expect(overview(), overview());
      expect(overview().hashCode, overview().hashCode);
    });

    test('should differ when any field differs', () {
      expect(overview(), isNot(overview(id: 't13')));
      expect(overview(), isNot(overview(number: 13)));
      expect(overview(), isNot(overview(centre: 'CIS Villefranche')));
      expect(overview(), isNot(overview(campaign: 2027)));
      expect(overview(), isNot(overview(members: 4)));
      expect(overview(), isNot(overview(requests: 2)));
      expect(overview(), isNot(overview(callerIsActive: false)));
    });

    test('should name the tournée and its team when printed', () {
      expect(
        '${overview()}',
        'TourneeOverview(t12, 12, CS Villefranche, 2026, 3 active, '
            '1 pending, caller in)',
      );
      expect(
        '${overview(callerIsActive: false)}',
        'TourneeOverview(t12, 12, CS Villefranche, 2026, 3 active, '
            '1 pending, caller out)',
      );
    });
  });
}
