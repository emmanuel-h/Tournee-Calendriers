// The tournées of Manu's phone (« Mes tournées », PLAN §5.3): the 49, which
// he created, the 12 he was accepted in, and the 7 where his request is
// still pending. All of the CS Villefranche (location privacy, CLAUDE.md).
// `sector12Visited` is the 12 as an admin who is not in it keeps it
// (PLAN §5.12).
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';

import '../../support/results.dart';
import 'sector_fixtures.dart';

final campaign2027 = valueOf(CampaignYear.create(2027));

/// A tournée of the CS Villefranche named [id], numbered [number].
SectorSummary summaryOf(
  String id,
  int number, {
  MemberStatus status = MemberStatus.active,
  CampaignYear? campaign,
}) => SectorSummary(
  id: SectorId(id),
  number: valueOf(SectorNumber.create(number)),
  centre: csVillefranche,
  campaign: campaign ?? campaign2026,
  status: status,
);

final sector49 = summaryOf('t49', 49);
final sector12 = summaryOf('t12', 12);
final sector7 = summaryOf('t7', 7, status: MemberStatus.pending);
final sector12Visited = summaryOf('t12', 12, status: MemberStatus.visiting);
