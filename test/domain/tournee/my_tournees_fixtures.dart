// The tournées of Manu's phone (« Mes tournées », PLAN §5.3): the 49, which
// he created, the 12 he was accepted in, and the 7 where his request is
// still pending. All of the CS Villefranche (location privacy, CLAUDE.md).
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

import '../../support/results.dart';
import 'tournee_fixtures.dart';

final campaign2027 = valueOf(CampaignYear.create(2027));

/// A tournée of the CS Villefranche named [id], numbered [number].
TourneeSummary summaryOf(
  String id,
  int number, {
  MemberStatus status = MemberStatus.active,
  CampaignYear? campaign,
}) => TourneeSummary(
  id: TourneeId(id),
  number: valueOf(TourneeNumber.create(number)),
  centre: csVillefranche,
  campaign: campaign ?? campaign2026,
  status: status,
);

final tournee49 = summaryOf('t49', 49);
final tournee12 = summaryOf('t12', 12);
final tournee7 = summaryOf('t7', 7, status: MemberStatus.pending);
