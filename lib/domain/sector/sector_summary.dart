import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';

/// What the phone keeps of one of the member's tournées, so « Mes
/// tournées » and the title « Tournée 49 · 2026 » show without the network
/// (PLAN §5.3, §6.3): its number, its centre de secours, the year being
/// worked on, and whether the member is in, still waiting, or an admin
/// visiting it without being in the team (PLAN §5.12).
///
/// A pending newcomer cannot read the tournée itself (PLAN §8.2): for a
/// request, this is what the join preview showed. An immutable value,
/// equal to another with the same fields.
final class SectorSummary {
  const SectorSummary({
    required this.id,
    required this.number,
    required this.centre,
    required this.campaign,
    required this.status,
  });

  final SectorId id;
  final SectorNumber number;
  final RescueCentre centre;

  /// The year whose streets the team works on.
  final CampaignYear campaign;

  /// Whether the member is in the tournée, their request still waits, or
  /// they visit it as an admin.
  final MemberStatus status;

  /// The request has not been accepted yet (« votre demande est en
  /// attente »): the tournée cannot be opened.
  bool get isPending => status == MemberStatus.pending;

  /// An admin opened it without being in its team (« · administrateur »).
  bool get isVisiting => status == MemberStatus.visiting;

  /// The same tournée once the member's request has been accepted, or the
  /// visiting admin has joined it.
  SectorSummary accepted() => SectorSummary(
    id: id,
    number: number,
    centre: centre,
    campaign: campaign,
    status: MemberStatus.active,
  );

  @override
  bool operator ==(Object other) =>
      other is SectorSummary &&
      other.id == id &&
      other.number == number &&
      other.centre == centre &&
      other.campaign == campaign &&
      other.status == status;

  @override
  int get hashCode => Object.hash(id, number, centre, campaign, status);

  @override
  String toString() =>
      'SectorSummary(${id.value}, ${number.value}, ${campaign.value}, '
      '${status.name})';
}
