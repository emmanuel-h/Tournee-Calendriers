// Shared values for the tournée tests: the team of the tournée 49 of the
// CS Villefranche (PLAN §5.8), with Manu who created it, Léa who was
// accepted, and Julie whose request is pending. Paul never asked to join.
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';

import '../../support/results.dart';

MemberName nameOf(String text) => valueOf(MemberName.create(text));

JoinCode codeOf(String text) => valueOf(JoinCode.parse(text));

final tourneeId = TourneeId('t49');
final number49 = valueOf(TourneeNumber.create(49));
final csVillefranche = valueOf(RescueCentre.create('CS Villefranche'));
final campaign2026 = valueOf(CampaignYear.create(2026));
final firstCode = codeOf('K7P-2QX');

final manuId = MemberId('uid-manu');
final leaId = MemberId('uid-lea');
final julieId = MemberId('uid-julie');
final paulId = MemberId('uid-paul');

final createdAt = DateTime.utc(2026, 10, 1, 18);
final leaAskedAt = DateTime.utc(2026, 10, 2, 9);
final leaAcceptedAt = DateTime.utc(2026, 10, 2, 9, 5);
final julieAskedAt = DateTime.utc(2026, 11, 2, 8, 12);

/// Manu, the creator: active since the tournée was created, accepted by
/// himself.
final manu = Member(
  id: manuId,
  name: nameOf('Manu'),
  requestedAt: createdAt,
  acceptance: ChangeStamp(by: manuId, at: createdAt),
);

/// Léa, accepted by Manu.
final lea = Member(
  id: leaId,
  name: nameOf('Léa'),
  requestedAt: leaAskedAt,
  acceptance: ChangeStamp(by: manuId, at: leaAcceptedAt),
);

/// Julie, waiting to be accepted.
final julie = Member(
  id: julieId,
  name: nameOf('Julie'),
  requestedAt: julieAskedAt,
);

/// The tournée with Manu, Léa and Julie, as storage gives it back.
Tournee team({JoinCode? joinCode, Iterable<Member>? members}) => valueOf(
  Tournee.create(
    id: tourneeId,
    number: number49,
    centre: csVillefranche,
    joinCode: joinCode ?? firstCode,
    createdBy: manuId,
    createdAt: createdAt,
    currentCampaign: campaign2026,
    members: members ?? [manu, lea, julie],
  ),
);
