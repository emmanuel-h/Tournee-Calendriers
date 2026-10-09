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
}
