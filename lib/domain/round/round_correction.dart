import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

// What « Corriger la tournée » and a forgotten house change on a validated
// tournée (PLAN §5.20, #168): the changes `RoundSummary` makes, which the
// ledger writes.

/// Why a validated tournée cannot be corrected as asked.
enum CorrectionFailure {
  /// « Don par don » on a tournée validated before #168: it has no list.
  noDonationList,

  /// A list longer than [mostDonations], the bound of the server's rules.
  tooManyDonations,

  /// A total of « Totaux » out of its bounds (`DonationTotals.isSound`).
  totalsNotSound,
}

/// The most dons a tournée's list may hold: the bound of the server's
/// rules (PLAN §8.2). A tournée is one outing, far below it.
const mostDonations = 2000;

/// A correction made to a validated tournée, for the ledger to write: its
/// new [totals], its new list of dons ([donations], null when « Totaux »
/// leaves the list as it was), when it was made, and how many houses it
/// adds to « maisons à marquer » ([housesAdded]).
///
/// Its start, end and « maisons visitées » never change here.
final class RoundCorrected {
  RoundCorrected({
    required this.totals,
    required List<Donation>? donations,
    required this.correctedAt,
    required this.housesAdded,
  }) : donations = donations == null ? null : List.unmodifiable(donations);

  final DonationTotals totals;

  /// The new list, in the order added; null: the list stays as it was.
  final List<Donation>? donations;

  /// « ✎ Corrigée le 15 nov. », the phone's clock, in UTC.
  final DateTime correctedAt;

  /// The paid dons and free calendars the correction added, when it added
  /// some (0 otherwise): as many houses the app did not count as visited.
  final int housesAdded;

  @override
  bool operator ==(Object other) =>
      other is RoundCorrected &&
      other.totals == totals &&
      sameOptionalItems(other.donations, donations) &&
      other.correctedAt == correctedAt &&
      other.housesAdded == housesAdded;

  @override
  int get hashCode => Object.hash(
    totals,
    donations == null ? null : Object.hashAll(donations!),
    correctedAt,
    housesAdded,
  );

  @override
  String toString() =>
      'RoundCorrected($totals, $donations, $correctedAt, +$housesAdded)';
}

/// What became of one of a tournée's « maisons à marquer ».
enum ForgottenHouse {
  /// « Marquer une maison »: a house made ✓, one more « maison visitée ».
  marked,

  /// « Ignorer »: one fewer to mark, nothing else.
  ignored,
}

/// No house is left to mark on the tournée: marked or ignored meanwhile
/// (another phone, another screen).
final class NoHouseToMark {
  const NoHouseToMark();

  @override
  bool operator ==(Object other) => other is NoHouseToMark;

  @override
  int get hashCode => (NoHouseToMark).hashCode;

  @override
  String toString() => 'NoHouseToMark';
}
