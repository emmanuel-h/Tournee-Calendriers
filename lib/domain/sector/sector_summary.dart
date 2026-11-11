import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';

/// What the phone keeps of one of the member's secteurs, so « Mes
/// secteurs » and the title « Secteur 49 · 2026 » show without the network
/// (PLAN §5.3, §6.3): its number, its centre de secours, the year being
/// worked on, whether the member is in, still waiting, or an admin
/// visiting it without being in the team (PLAN §5.12), and the name they go
/// by in it (#148, PLAN §5.16).
///
/// A pending newcomer cannot read the secteur itself (PLAN §8.2): for a
/// request, this is what the join preview showed. An immutable value,
/// equal to another with the same fields.
final class SectorSummary {
  const SectorSummary({
    required this.id,
    required this.number,
    required this.centre,
    required this.campaign,
    required this.status,
    this.memberName,
  });

  final SectorId id;
  final SectorNumber number;
  final RescueCentre centre;

  /// The year whose streets the team works on.
  final CampaignYear campaign;

  /// Whether the member is in the secteur, their request still waits, or
  /// they visit it as an admin.
  final MemberStatus status;

  /// The name the member goes by in this secteur: the phone's prénom
  /// unless it was taken there (names are unique within a secteur, PLAN
  /// §5.16). Null when the phone does not know it (a secteur kept before
  /// #148, an admin's visit): the prénom, then.
  final MemberName? memberName;

  /// The request has not been accepted yet (« votre demande est en
  /// attente »): the secteur cannot be opened.
  bool get isPending => status == MemberStatus.pending;

  /// An admin opened it without being in its team (« · administrateur »).
  bool get isVisiting => status == MemberStatus.visiting;

  /// The same secteur once the member's request has been accepted, or the
  /// visiting admin has joined it.
  SectorSummary accepted() => SectorSummary(
    id: id,
    number: number,
    centre: centre,
    campaign: campaign,
    status: MemberStatus.active,
    memberName: memberName,
  );

  /// The same secteur, where the member now goes by [name].
  SectorSummary withMemberName(MemberName name) => SectorSummary(
    id: id,
    number: number,
    centre: centre,
    campaign: campaign,
    status: status,
    memberName: name,
  );

  @override
  bool operator ==(Object other) =>
      other is SectorSummary &&
      other.id == id &&
      other.number == number &&
      other.centre == centre &&
      other.campaign == campaign &&
      other.status == status &&
      other.memberName == memberName;

  @override
  int get hashCode =>
      Object.hash(id, number, centre, campaign, status, memberName);

  @override
  String toString() =>
      'SectorSummary(${id.value}, ${number.value}, ${campaign.value}, '
      '${status.name})';
}
