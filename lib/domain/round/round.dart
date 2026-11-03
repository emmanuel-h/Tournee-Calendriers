import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

/// No don at the place asked: the list on screen was older than the
/// tournée (a don removed meanwhile).
final class NoSuchDonation {
  const NoSuchDonation();

  @override
  bool operator ==(Object other) => other is NoSuchDonation;

  @override
  int get hashCode => (NoSuchDonation).hashCode;

  @override
  String toString() => 'NoSuchDonation';
}

/// The tournée on (PLAN §2, §5.13): one outing of the member of this phone
/// on a secteur, from « Commencer une tournée » to « Valider la tournée ».
///
/// An aggregate kept on the phone only: its dons stay here until it is
/// validated, then only its [RoundSummary] leaves. It names no member (the
/// phone's own) and its dons name no house and no time (PLAN §8.3).
///
/// Immutable: each command returns a new tournée, which the use case saves.
final class Round {
  Round._({
    required this.id,
    required this.sector,
    required this.campaign,
    required this.startedAt,
    required this.housesVisited,
    required List<Donation> donations,
  }) : donations = List.unmodifiable(donations);

  /// A tournée of [campaign] of [sector] started [at], nothing in it yet.
  factory Round.start({
    required RoundId id,
    required SectorId sector,
    required CampaignYear campaign,
    required DateTime at,
  }) => Round._(
    id: id,
    sector: sector,
    campaign: campaign,
    startedAt: at,
    housesVisited: 0,
    donations: const [],
  );

  /// A tournée as the phone kept it. Throws an [ArgumentError] on a
  /// negative [housesVisited]: the storage mapper checks it first.
  factory Round.restore({
    required RoundId id,
    required SectorId sector,
    required CampaignYear campaign,
    required DateTime startedAt,
    required int housesVisited,
    required List<Donation> donations,
  }) {
    if (housesVisited < 0) {
      throw ArgumentError.value(housesVisited, 'housesVisited', 'negative');
    }
    return Round._(
      id: id,
      sector: sector,
      campaign: campaign,
      startedAt: startedAt,
      housesVisited: housesVisited,
      donations: donations,
    );
  }

  final RoundId id;

  /// The secteur it started in: its card shows only there.
  final SectorId sector;

  /// The campaign its summary goes to.
  final CampaignYear campaign;

  /// « Commencer une tournée », in UTC.
  final DateTime startedAt;

  /// The houses and doors made ✓ or ⊘ during the tournée, less those
  /// undone (« 23 maisons visitées »). Never negative.
  final int housesVisited;

  /// The dons in the order they were added; « Dons de la tournée » shows
  /// them newest first. An index into this list names a don.
  final List<Donation> donations;

  /// What the dons add up to (« 19 dons · 280 € »).
  DonationTotals get totals => DonationTotals.of(donations);

  /// Whether [index] names a don of [donations].
  bool _holds(int index) => index >= 0 && index < donations.length;

  /// This tournée with [donation] added last.
  Round add(Donation donation) => _with(donations: [...donations, donation]);

  /// This tournée with the don at [index] replaced by [donation]
  /// (« Modifier le don »).
  Result<Round, NoSuchDonation> replace(int index, Donation donation) {
    if (!_holds(index)) return const Err(NoSuchDonation());
    return Ok(_with(donations: [...donations]..[index] = donation));
  }

  /// This tournée without the don at [index] (« Supprimer ce don »).
  Result<Round, NoSuchDonation> remove(int index) {
    if (!_holds(index)) return const Err(NoSuchDonation());
    return Ok(_with(donations: [...donations]..removeAt(index)));
  }

  /// One more house or door made ✓ or ⊘.
  Round visited() => _with(housesVisited: housesVisited + 1);

  /// One house or door less: a ✓ or ⊘ undone. Never below 0, as a mark made
  /// before the tournée may be undone during it.
  Round unvisited() =>
      housesVisited == 0 ? this : _with(housesVisited: housesVisited - 1);

  /// The summary of this tournée validated [at]: all that leaves the phone.
  ///
  /// It ends after it started, whatever the phone's clock did meanwhile
  /// (set back by hand): at least one second after [startedAt], which the
  /// server's rules require (PLAN §8.2).
  RoundSummary validate(DateTime at) {
    final earliest = startedAt.add(const Duration(seconds: 1));
    return RoundSummary(
      id: id,
      startedAt: startedAt,
      endedAt: at.isBefore(earliest) ? earliest : at,
      housesVisited: housesVisited,
      totals: totals,
    );
  }

  Round _with({int? housesVisited, List<Donation>? donations}) => Round._(
    id: id,
    sector: sector,
    campaign: campaign,
    startedAt: startedAt,
    housesVisited: housesVisited ?? this.housesVisited,
    donations: donations ?? this.donations,
  );

  @override
  bool operator ==(Object other) =>
      other is Round &&
      other.id == id &&
      other.sector == sector &&
      other.campaign == campaign &&
      other.startedAt == startedAt &&
      other.housesVisited == housesVisited &&
      sameItems(other.donations, donations);

  @override
  int get hashCode => Object.hash(
    id,
    sector,
    campaign,
    startedAt,
    housesVisited,
    Object.hashAll(donations),
  );

  @override
  String toString() =>
      'Round(${id.value}, ${sector.value}, ${campaign.value}, $startedAt, '
      '$housesVisited houses, $donations)';
}
