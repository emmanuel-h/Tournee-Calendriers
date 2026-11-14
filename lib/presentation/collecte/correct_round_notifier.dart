import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_notifier.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_view.dart';
import 'package:tournee_calendriers/presentation/collecte/correct_round_view.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';

/// « Corriger la tournée » of one validated tournée of « Collecte ».
///
/// `family`: one per tournée id. `autoDispose`: the draft is forgotten
/// once the screen is left.
final correctRoundProvider = NotifierProvider.autoDispose
    .family<CorrectRoundNotifier, CorrectRoundView, RoundId>(
      CorrectRoundNotifier.new,
    );

/// Holds what the member changes in « Corriger la tournée » (PLAN §5.20)
/// until « Enregistrer »: the list of dons (« Don par don ») and the
/// figures typed (« Totaux »), each tab its own draft; « Enregistrer »
/// saves the tab shown (`CorrectRoundDonations` or `CorrectRoundTotals`).
///
/// The tournée comes from « Collecte », which the screen opens from:
/// watching it keeps it read; the draft starts from the tournée as it was
/// then, and a teammate's change meanwhile does not undo what is typed
/// (« the last one sent wins »).
final class CorrectRoundNotifier extends Notifier<CorrectRoundView> {
  CorrectRoundNotifier(this.round);

  final RoundId round;

  /// The tournée as it was when the screen opened.
  CollecteRound? _original;
  var _tab = CorrectionTab.donByDon;
  var _donations = const <Donation>[];
  var _counts = const <PaymentMethod, int>{};

  /// What « Montant » holds per method once typed in; the tournée's own
  /// amount until then.
  var _amounts = const <PaymentMethod, String>{};
  var _free = 0;

  @override
  CorrectRoundView build() {
    // `select`: built again only when this tournée changes, not for every
    // other tournée of the collecte.
    final shown = ref.watch(
      collecteProvider.select(
        (view) => switch (view) {
          CollecteShown(:final rounds) =>
            rounds.where((each) => each.id == round).firstOrNull,
          CollecteLoading() || CollecteUnavailable() => null,
        },
      ),
    );
    if (_original == null && shown != null) _start(shown);
    return _render();
  }

  void _start(CollecteRound shown) {
    _original = shown;
    _tab = shown.donations == null
        ? CorrectionTab.totals
        : CorrectionTab.donByDon;
    _donations = shown.donations ?? const [];
    _counts = {
      for (final method in PaymentMethod.values)
        method: shown.totals.of(method).count,
    };
    _amounts = const {};
    _free = shown.totals.free;
  }

  /// « Don par don » or « Totaux ». Nothing changes without a list.
  void selectTab(CorrectionTab tab) {
    if (_original?.donations == null) return;
    _tab = tab;
    _show();
  }

  /// « Valider » of « Nouveau don »: [donation] last in the list.
  void addDonation(Donation donation) {
    _donations = [..._donations, donation];
    _show();
  }

  /// « Valider » of « Modifier le don »: the don at [index] (in the order
  /// added) becomes [donation].
  void changeDonation(int index, Donation donation) {
    if (index < 0 || index >= _donations.length) return;
    _donations = [..._donations]..[index] = donation;
    _show();
  }

  /// « Supprimer ce don »: the don at [index] (in the order added) goes.
  void removeDonation(int index) {
    if (index < 0 || index >= _donations.length) return;
    _donations = [..._donations]..removeAt(index);
    _show();
  }

  /// « Dons » of [method] is now [count].
  void setCount(PaymentMethod method, int count) {
    _counts = {..._counts, method: count};
    _show();
  }

  /// « Montant » of [method] now holds [text].
  void setAmount(PaymentMethod method, String text) {
    _amounts = {..._amounts, method: text};
    _show();
  }

  /// « Calendriers offerts » is now [count].
  void setFree(int count) {
    _free = count;
    _show();
  }

  /// « Corriger » of the confirmation: saves the tab shown. Returns whether
  /// it was saved: false when the tournée is gone, or the figures cannot
  /// stand (the button was greyed).
  Future<bool> save() async {
    final sector = ref.read(currentSectorProvider);
    final view = state;
    if (sector == null || view is! CorrectRoundShown || !view.canSave) {
      return false;
    }
    final place = (sector: sector.id, campaign: sector.campaign, round: round);
    final saved = switch (_tab) {
      CorrectionTab.donByDon => await ref.read(correctRoundDonationsProvider)(
        place,
        _donations,
      ),
      CorrectionTab.totals => await ref.read(correctRoundTotalsProvider)(
        place,
        view.after,
      ),
    };
    return saved is Ok;
  }

  void _show() => state = _render();

  CorrectRoundView _render() {
    final original = _original;
    if (original == null) return const CorrectRoundGone();
    final drafts = {
      for (final method in PaymentMethod.values) method: _draftOf(method),
    };
    MethodTotal typed(PaymentMethod method) => MethodTotal(
      count: drafts[method]!.count,
      cents: drafts[method]!.cents ?? 0,
    );
    final typedTotals = DonationTotals(
      cash: typed(PaymentMethod.cash),
      cheque: typed(PaymentMethod.cheque),
      card: typed(PaymentMethod.card),
      free: _free,
    );
    final freeFailure = typedTotals.freeFailure;
    final (after, changed, canSave) = switch (_tab) {
      CorrectionTab.donByDon => (
        DonationTotals.of(_donations),
        !sameItems(_donations, original.donations ?? const []),
        _donations.length <= mostDonations,
      ),
      CorrectionTab.totals => (
        typedTotals,
        typedTotals != original.totals,
        freeFailure == null && drafts.values.every((draft) => !draft.isFaulty),
      ),
    };
    return CorrectRoundShown(
      startedAt: original.startedAt,
      endedAt: original.endedAt,
      housesVisited: original.housesVisited,
      tab: _tab,
      hasList: original.donations != null,
      donations: donationRowsOf(_donations),
      cash: drafts[PaymentMethod.cash]!,
      cheque: drafts[PaymentMethod.cheque]!,
      card: drafts[PaymentMethod.card]!,
      free: _free,
      freeFailure: freeFailure,
      before: original.totals,
      after: after,
      changed: changed,
      canSave: canSave,
    );
  }

  /// The line of [method] as typed: its count, its amount read (the
  /// tournée's own until typed in), and what is wrong with them.
  MethodDraft _draftOf(PaymentMethod method) {
    final count = _counts[method]!;
    final text = _amounts[method];
    final read = text == null
        ? Ok<int, AmountFailure>(_original!.totals.of(method).cents)
        : Amount.parseSum(text);
    return switch (read) {
      Ok(value: final cents) => MethodDraft(
        count: count,
        cents: cents,
        totalFailure: MethodTotal(count: count, cents: cents).failure,
      ),
      Err(:final failure) => MethodDraft(
        count: count,
        cents: null,
        amountFailure: failure,
      ),
    };
  }
}
