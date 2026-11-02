import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';

import '../../support/results.dart';
import 'my_sectors_fixtures.dart';
import 'sector_fixtures.dart';

void main() {
  test('should keep what « Mes tournées » shows of a tournée', () {
    final summary = summaryOf('t49', 49, campaign: campaign2027);

    expect(summary.id, SectorId('t49'));
    expect(summary.number.value, 49);
    expect(summary.centre, csVillefranche);
    expect(summary.campaign, campaign2027);
    expect(summary.status, MemberStatus.active);
  });

  test('should be pending when the request is not accepted yet', () {
    expect(sector7.isPending, isTrue);
    expect(sector49.isPending, isFalse);
  });

  test('should be visited when an admin opened it without being in it', () {
    expect(sector12Visited.isVisiting, isTrue);
    expect(sector12Visited.isPending, isFalse);
    expect(sector49.isVisiting, isFalse);
    expect(sector7.isVisiting, isFalse);
  });

  test('should be active, all else kept, once the visiting admin joins', () {
    final joined = sector12Visited.accepted();

    expect(joined.status, MemberStatus.active);
    expect(joined.id, sector12Visited.id);
    expect(joined.number, sector12Visited.number);
    expect(joined.centre, sector12Visited.centre);
    expect(joined.campaign, sector12Visited.campaign);
  });

  test('should be active, all else kept, once the request is accepted', () {
    final accepted = sector7.accepted();

    expect(accepted.status, MemberStatus.active);
    expect(accepted.id, sector7.id);
    expect(accepted.number, sector7.number);
    expect(accepted.centre, sector7.centre);
    expect(accepted.campaign, sector7.campaign);
  });

  test('should be equal when every field is', () {
    expect(summaryOf('t49', 49), sector49);
    expect(summaryOf('t49', 49).hashCode, sector49.hashCode);
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
      sector49 ==
          SectorSummary(
            id: sector49.id,
            number: sector49.number,
            centre: valueOf(RescueCentre.create('CS Villefranche-sur-Saône')),
            campaign: sector49.campaign,
            status: sector49.status,
          ),
      isFalse,
    );
  });

  test('should name its id and number when printed', () {
    expect(sector49.toString(), 'SectorSummary(t49, 49, 2026, active)');
  });
}
