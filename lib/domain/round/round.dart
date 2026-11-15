import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_origin.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/donations_taken_out.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
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
/// An aggregate kept on the phone only until it is validated; then only
/// its [RoundSummary] leaves, its dons in it (#168: method and amount). It names no member (the
/// phone's own) and its dons name no house and no time (PLAN §8.3).
///
/// While it is on, it remembers which house or door each don was noted
/// from, when one was ([origins], PLAN §5.21), so a ✓ taken back takes its
/// own dons out ([takeOut]). [validate] leaves that behind.
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
    required List<DonationOrigin?> origins,
  }) : donations = List.unmodifiable(donations),
       origins = List.unmodifiable(origins);

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
    origins: const [],
  );

  /// A tournée as the phone kept it, [origins] beside its [donations] (none
  /// linked when not given: a file written before #169). Throws an
  /// [ArgumentError] on a negative [housesVisited], or [origins] not as
  /// many as the dons: the storage mapper checks both first.
  factory Round.restore({
    required RoundId id,
    required SectorId sector,
    required CampaignYear campaign,
    required DateTime startedAt,
    required int housesVisited,
    required List<Donation> donations,
    List<DonationOrigin?>? origins,
  }) {
    if (housesVisited < 0) {
      throw ArgumentError.value(housesVisited, 'housesVisited', 'negative');
    }
    if (origins != null && origins.length != donations.length) {
      throw ArgumentError.value(origins, 'origins', 'not one per don');
    }
    return Round._(
      id: id,
      sector: sector,
      campaign: campaign,
      startedAt: startedAt,
      housesVisited: housesVisited,
      donations: donations,
      origins: origins ?? List.filled(donations.length, null),
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

  /// Beside each don of [donations], at the same index, the house or door
  /// it was noted from; null for one given from « Dons de la tournée »
  /// (PLAN §5.21). On the phone only.
  final List<DonationOrigin?> origins;

  /// What the dons add up to (« 19 dons · 280 € »).
  DonationTotals get totals => DonationTotals.of(donations);

  /// Whether [index] names a don of [donations].
  bool _holds(int index) => index >= 0 && index < donations.length;

  /// This tournée with [donation] added last, linked to the house or door
  /// it was noted [from], if any.
  Round add(Donation donation, {DonationOrigin? from}) =>
      _with(donations: [...donations, donation], origins: [...origins, from]);

  /// This tournée with the don at [index] replaced by [donation]
  /// (« Modifier le don »); it stays linked to its house or door.
  Result<Round, NoSuchDonation> replace(int index, Donation donation) {
    if (!_holds(index)) return const Err(NoSuchDonation());
    return Ok(_with(donations: [...donations]..[index] = donation));
  }

  /// This tournée without the don at [index] (« Supprimer ce don »), and
  /// without its link.
  Result<Round, NoSuchDonation> remove(int index) {
    if (!_holds(index)) return const Err(NoSuchDonation());
    return Ok(
      _with(
        donations: [...donations]..removeAt(index),
        origins: [...origins]..removeAt(index),
      ),
    );
  }

  /// This tournée without the dons linked to [origin], a ✓ taken back
  /// (PLAN §5.21), and those dons with their places, for the snackbar and
  /// its « Annuler » ([putBack]). Nothing is taken out when none is linked
  /// to it: the tournée is then this one.
  (Round, DonationsTakenOut) takeOut(DonationOrigin origin) {
    final taken = <DonationTakenOut>[];
    final keptDonations = <Donation>[];
    final keptOrigins = <DonationOrigin?>[];
    for (var index = 0; index < donations.length; index++) {
      if (origins[index] == origin) {
        taken.add((index: index, donation: donations[index]));
      } else {
        keptDonations.add(donations[index]);
        keptOrigins.add(origins[index]);
      }
    }
    final out = DonationsTakenOut(round: id, origin: origin, taken: taken);
    if (taken.isEmpty) return (this, out);
    return (_with(donations: keptDonations, origins: keptOrigins), out);
  }

  /// This tournée with the dons [taken] out put back (« Annuler »), each at
  /// its place and linked to its house or door again. A place past the end
  /// (dons removed since) puts it last. Dons taken out of another tournée
  /// are not put back: this one is unchanged.
  Round putBack(DonationsTakenOut taken) {
    if (taken.round != id || taken.isEmpty) return this;
    final backDonations = [...donations];
    final backOrigins = [...origins];
    // The first place first: each one put back is where it was among the
    // ones before it.
    for (final (:index, :donation) in taken.taken) {
      final at = index < backDonations.length ? index : backDonations.length;
      backDonations.insert(at, donation);
      backOrigins.insert(at, taken.origin);
    }
    return _with(donations: backDonations, origins: backOrigins);
  }

  /// One more house or door made ✓ or ⊘.
  Round visited() => _with(housesVisited: housesVisited + 1);

  /// One house or door less: a ✓ or ⊘ undone. Never below 0, as a mark made
  /// before the tournée may be undone during it.
  Round unvisited() =>
      housesVisited == 0 ? this : _with(housesVisited: housesVisited - 1);

  /// This tournée validated [at] (« Valider la tournée »): a tournée
  /// « validated, not yet sent » ([UnsentRound]), waiting for the server to
  /// have its summary, all that leaves the phone: its figures and its dons
  /// in order, without a house or a time (PLAN §5.20).
  ///
  /// The links of [origins] stay behind: a don sent names no house.
  ///
  /// It ends after it started, whatever the phone's clock did meanwhile
  /// (set back by hand): at least one second after [startedAt], which the
  /// server's rules require (PLAN §8.2).
  UnsentRound validate(DateTime at) {
    final earliest = startedAt.add(const Duration(seconds: 1));
    return UnsentRound(
      sector: sector,
      campaign: campaign,
      summary: RoundSummary(
        id: id,
        startedAt: startedAt,
        endedAt: at.isBefore(earliest) ? earliest : at,
        housesVisited: housesVisited,
        totals: totals,
        donations: donations,
      ),
    );
  }

  Round _with({
    int? housesVisited,
    List<Donation>? donations,
    List<DonationOrigin?>? origins,
  }) => Round._(
    id: id,
    sector: sector,
    campaign: campaign,
    startedAt: startedAt,
    housesVisited: housesVisited ?? this.housesVisited,
    donations: donations ?? this.donations,
    origins: origins ?? this.origins,
  );

  @override
  bool operator ==(Object other) =>
      other is Round &&
      other.id == id &&
      other.sector == sector &&
      other.campaign == campaign &&
      other.startedAt == startedAt &&
      other.housesVisited == housesVisited &&
      sameItems(other.donations, donations) &&
      sameItems(other.origins, origins);

  @override
  int get hashCode => Object.hash(
    id,
    sector,
    campaign,
    startedAt,
    housesVisited,
    Object.hashAll(donations),
    Object.hashAll(origins),
  );

  @override
  String toString() =>
      'Round(${id.value}, ${sector.value}, ${campaign.value}, $startedAt, '
      '$housesVisited houses, $donations)';
}
