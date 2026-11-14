import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';

// The view state of « Corriger la tournée » (PLAN §5.20, mockups
// RoundCorrectDons, RoundCorrect, RoundCorrectConfirm), as plain data
// tested without widgets.

/// « Don par don | Totaux ».
enum CorrectionTab {
  /// The list of dons, the totals worked out from it.
  donByDon,

  /// The count and amount per method and the calendars offered, the list
  /// left as it is.
  totals,
}

/// What the screen shows. `sealed`: it handles each case.
sealed class CorrectRoundView {
  const CorrectRoundView();
}

/// The tournée is not among those of « Collecte » (gone meanwhile, or not
/// read yet): nothing to correct.
final class CorrectRoundGone extends CorrectRoundView {
  const CorrectRoundGone();

  @override
  bool operator ==(Object other) => other is CorrectRoundGone;

  @override
  int get hashCode => (CorrectRoundGone).hashCode;
}

/// One method of « Totaux »: « Dons » and « Montant », and why they cannot
/// stand, under the line.
final class MethodDraft {
  const MethodDraft({
    required this.count,
    required this.cents,
    this.amountFailure,
    this.totalFailure,
  });

  /// « Dons », as typed.
  final int count;

  /// « Montant » read, in cents; null when it cannot be read
  /// ([amountFailure] says why).
  final int? cents;

  /// Why « Montant » cannot be read (« Entrez un montant valide. »).
  final AmountFailure? amountFailure;

  /// Why the count and the amount cannot go together (« Un montant pour 8
  /// dons. »); null when they can, or when the amount cannot be read.
  final TotalFailure? totalFailure;

  /// Whether the line is wrong: « Enregistrer » waits for it.
  bool get isFaulty => amountFailure != null || totalFailure != null;

  @override
  bool operator ==(Object other) =>
      other is MethodDraft &&
      other.count == count &&
      other.cents == cents &&
      other.amountFailure == amountFailure &&
      other.totalFailure == totalFailure;

  @override
  int get hashCode => Object.hash(count, cents, amountFailure, totalFailure);

  @override
  String toString() =>
      'MethodDraft($count, $cents, $amountFailure, $totalFailure)';
}

/// The tournée being corrected.
final class CorrectRoundShown extends CorrectRoundView {
  CorrectRoundShown({
    required this.startedAt,
    required this.endedAt,
    required this.housesVisited,
    required this.tab,
    required this.hasList,
    required List<DonationRow> donations,
    required this.cash,
    required this.cheque,
    required this.card,
    required this.free,
    required this.freeFailure,
    required this.before,
    required this.after,
    required this.changed,
    required this.canSave,
  }) : donations = List.unmodifiable(donations);

  /// « Sam. 14 nov. · 14:05 → 18:20 · 23 maisons », at the phone's time.
  final DateTime startedAt;
  final DateTime endedAt;
  final int housesVisited;

  /// The tab shown; always [CorrectionTab.totals] without a list.
  final CorrectionTab tab;

  /// « Don par don | Totaux » shows: the tournée kept its dons (#168).
  final bool hasList;

  /// The dons as corrected so far, newest first (« Don par don »).
  final List<DonationRow> donations;

  /// « Totaux », as typed.
  final MethodDraft cash;
  final MethodDraft cheque;
  final MethodDraft card;

  /// « Calendriers offerts », as typed, and why it cannot stand.
  final int free;
  final TotalFailure? freeFailure;

  /// The tournée's totals before the correction.
  final DonationTotals before;

  /// Its totals as the tab shown would save them: worked out from the
  /// dons (« 20 dons · 205 € · touchez un don… »), or as typed in
  /// « Totaux » (« Total 20 dons · 205 € », an amount that cannot be read
  /// counted as none).
  final DonationTotals after;

  /// Something differs from the tournée: « Enregistrer » asks first;
  /// otherwise it just goes back.
  final bool changed;

  /// « Enregistrer » is red, not greyed: nothing under a line is wrong.
  final bool canSave;

  /// The line of [method] in « Totaux ».
  MethodDraft of(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => cash,
    PaymentMethod.cheque => cheque,
    PaymentMethod.card => card,
  };

  @override
  bool operator ==(Object other) =>
      other is CorrectRoundShown &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.housesVisited == housesVisited &&
      other.tab == tab &&
      other.hasList == hasList &&
      sameItems(other.donations, donations) &&
      other.cash == cash &&
      other.cheque == cheque &&
      other.card == card &&
      other.free == free &&
      other.freeFailure == freeFailure &&
      other.before == before &&
      other.after == after &&
      other.changed == changed &&
      other.canSave == canSave;

  @override
  int get hashCode => Object.hash(
    startedAt,
    endedAt,
    housesVisited,
    tab,
    hasList,
    Object.hashAll(donations),
    cash,
    cheque,
    card,
    free,
    freeFailure,
    before,
    after,
    changed,
    canSave,
  );
}
