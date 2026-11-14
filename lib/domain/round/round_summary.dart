import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

/// What is left of a validated tournée (PLAN §5.13, §5.20, §6.1): when it
/// ran, how many houses were visited, its totals per payment method and of
/// free calendars, and the list of its dons.
///
/// **No member**, and its dons name **no house and no time**: this is all
/// that leaves the phone, and the whole secteur sees it in « Collecte ».
///
/// Any member may correct it afterwards (« Corriger la tournée », #168):
/// [correctDonations] and [correctTotals] give the summary corrected and
/// the change for the ledger; its start, end and houses visited never
/// change there. A correction that adds dons leaves « maisons à marquer »
/// ([housesToMark]), each then marked or ignored ([settleForgottenHouse]).
///
/// An immutable value, equal to another with the same fields.
final class RoundSummary {
  /// Throws an [ArgumentError] on a negative [housesVisited] or
  /// [housesToMark]: the mappers check them first.
  RoundSummary({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.housesVisited,
    required this.totals,
    List<Donation>? donations,
    this.correctedAt,
    this.housesToMark = 0,
  }) : donations = donations == null ? null : List.unmodifiable(donations) {
    if (housesVisited < 0) {
      throw ArgumentError.value(housesVisited, 'housesVisited', 'negative');
    }
    if (housesToMark < 0) {
      throw ArgumentError.value(housesToMark, 'housesToMark', 'negative');
    }
  }

  /// The tournée's own id, so its summary is stored once however often it
  /// is sent.
  final RoundId id;

  /// « Commencer une tournée », in UTC.
  final DateTime startedAt;

  /// « Valider la tournée », in UTC; always after [startedAt].
  final DateTime endedAt;

  /// The houses and doors made ✓ or ⊘ during the tournée (« 23 maisons »),
  /// and the forgotten ones marked since.
  final int housesVisited;

  final DonationTotals totals;

  /// The dons in the order added (« Voir les 19 dons »); null for a
  /// tournée validated before #168, which sent none.
  final List<Donation>? donations;

  /// When it was last corrected (« ✎ Corrigée le 15 nov. »), in UTC; null
  /// when never.
  final DateTime? correctedAt;

  /// « ⚠ 1 maison à marquer »: houses its corrections added that nobody
  /// has marked or ignored yet.
  final int housesToMark;

  /// « ⚠ La liste des dons ne correspond plus aux totaux. »: the list no
  /// longer adds up to [totals] (« Totaux » changed them). Computed, never
  /// stored; false without a list.
  bool get listDiffersFromTotals {
    final donations = this.donations;
    return donations != null && DonationTotals.of(donations) != totals;
  }

  /// « Don par don »: the list becomes [donations], and the totals are
  /// worked out again from it, corrected [at]. Refused without a list
  /// (a tournée validated before #168), or past [mostDonations].
  Result<(RoundSummary, RoundCorrected), CorrectionFailure> correctDonations(
    List<Donation> donations, {
    required DateTime at,
  }) {
    if (this.donations == null) {
      return const Err(CorrectionFailure.noDonationList);
    }
    if (donations.length > mostDonations) {
      return const Err(CorrectionFailure.tooManyDonations);
    }
    return Ok(_corrected(DonationTotals.of(donations), donations, at));
  }

  /// « Totaux »: the totals become [totals], corrected [at]; the list stays
  /// as it was, and shows as differing when it no longer adds up. Refused
  /// when a total is out of its bounds (`DonationTotals.isSound`).
  Result<(RoundSummary, RoundCorrected), CorrectionFailure> correctTotals(
    DonationTotals totals, {
    required DateTime at,
  }) {
    if (!totals.isSound) return const Err(CorrectionFailure.totalsNotSound);
    return Ok(_corrected(totals, null, at));
  }

  /// The paid dons and free calendars [after] holds beyond [totals], when
  /// it holds more: each was a house visited that nobody marked.
  int _housesAddedBy(DonationTotals after) {
    final added = after.count + after.free - (totals.count + totals.free);
    return added > 0 ? added : 0;
  }

  (RoundSummary, RoundCorrected) _corrected(
    DonationTotals after,
    List<Donation>? donations,
    DateTime at,
  ) {
    final added = _housesAddedBy(after);
    return (
      _with(
        totals: after,
        donations: donations ?? this.donations,
        correctedAt: at,
        housesToMark: housesToMark + added,
      ),
      RoundCorrected(
        totals: after,
        donations: donations,
        correctedAt: at,
        housesAdded: added,
      ),
    );
  }

  /// One of the « maisons à marquer » [how] (marked: one more house
  /// visited too). Refused when none is left.
  Result<(RoundSummary, ForgottenHouse), NoHouseToMark> settleForgottenHouse(
    ForgottenHouse how,
  ) {
    if (housesToMark == 0) return const Err(NoHouseToMark());
    return Ok((
      _with(
        housesVisited: switch (how) {
          ForgottenHouse.marked => housesVisited + 1,
          ForgottenHouse.ignored => housesVisited,
        },
        housesToMark: housesToMark - 1,
      ),
      how,
    ));
  }

  RoundSummary _with({
    int? housesVisited,
    DonationTotals? totals,
    List<Donation>? donations,
    DateTime? correctedAt,
    // Every change counts its houses to mark again: never left out.
    required int housesToMark,
  }) => RoundSummary(
    id: id,
    startedAt: startedAt,
    endedAt: endedAt,
    housesVisited: housesVisited ?? this.housesVisited,
    totals: totals ?? this.totals,
    donations: donations ?? this.donations,
    correctedAt: correctedAt ?? this.correctedAt,
    housesToMark: housesToMark,
  );

  @override
  bool operator ==(Object other) =>
      other is RoundSummary &&
      other.id == id &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.housesVisited == housesVisited &&
      other.totals == totals &&
      sameOptionalItems(other.donations, donations) &&
      other.correctedAt == correctedAt &&
      other.housesToMark == housesToMark;

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    housesVisited,
    totals,
    donations == null ? null : Object.hashAll(donations!),
    correctedAt,
    housesToMark,
  );

  @override
  String toString() =>
      'RoundSummary(${id.value}, $startedAt → $endedAt, '
      '$housesVisited houses, $totals, ${donations?.length} dons, '
      'corrected $correctedAt, $housesToMark to mark)';
}
