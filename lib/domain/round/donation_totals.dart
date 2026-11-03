import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';

/// The dons of one payment method added up (« Espèces · 15 dons · 210 € »,
/// PLAN §5.13): how many, and their sum in cents.
final class MethodTotal {
  /// Throws an [ArgumentError] on a negative [count] or [cents]: totals are
  /// sums the app makes, so a negative one is a bug, not a user error.
  MethodTotal({required this.count, required this.cents}) {
    if (count < 0) throw ArgumentError.value(count, 'count', 'negative');
    if (cents < 0) throw ArgumentError.value(cents, 'cents', 'negative');
  }

  const MethodTotal._none() : count = 0, cents = 0;

  /// No don: the starting point of a sum.
  static const none = MethodTotal._none();

  final int count;
  final int cents;

  /// This total with one more don of [amount].
  MethodTotal adding(Amount amount) =>
      MethodTotal(count: count + 1, cents: cents + amount.cents);

  MethodTotal operator +(MethodTotal other) =>
      MethodTotal(count: count + other.count, cents: cents + other.cents);

  @override
  bool operator ==(Object other) =>
      other is MethodTotal && other.count == count && other.cents == cents;

  @override
  int get hashCode => Object.hash(count, cents);

  @override
  String toString() => 'MethodTotal($count, $cents)';
}

/// What a tournée, or a whole campaign, collected (« ARGENT RÉCOLTÉ »,
/// PLAN §5.13): a [MethodTotal] per payment method, and the calendars given
/// for free.
///
/// Never split per member, by decision: nothing here names one.
final class DonationTotals {
  /// Throws an [ArgumentError] on a negative [free] (see [MethodTotal]).
  DonationTotals({
    required this.cash,
    required this.cheque,
    required this.card,
    required this.free,
  }) {
    if (free < 0) throw ArgumentError.value(free, 'free', 'negative');
  }

  const DonationTotals._none()
    : cash = MethodTotal.none,
      cheque = MethodTotal.none,
      card = MethodTotal.none,
      free = 0;

  /// No don at all: « 0 don · 0 € ».
  static const none = DonationTotals._none();

  /// The dons of [donations] added up.
  factory DonationTotals.of(Iterable<Donation> donations) =>
      donations.fold(none, (totals, donation) => totals.adding(donation));

  final MethodTotal cash;
  final MethodTotal cheque;
  final MethodTotal card;

  /// The calendars given for free (« 2 calendriers offerts »).
  final int free;

  /// The total of [method].
  MethodTotal of(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => cash,
    PaymentMethod.cheque => cheque,
    PaymentMethod.card => card,
  };

  /// The dons paid, every method together (« 19 dons »). A calendar given
  /// for free is not a don of money: it counts in [free] only.
  int get count => cash.count + cheque.count + card.count;

  /// The money of every method together, in cents (« 280 € »).
  int get cents => cash.cents + cheque.cents + card.cents;

  /// These totals with [donation] added.
  DonationTotals adding(Donation donation) => switch (donation) {
    PaidDonation(:final method, :final amount) => DonationTotals(
      cash: method == PaymentMethod.cash ? cash.adding(amount) : cash,
      cheque: method == PaymentMethod.cheque ? cheque.adding(amount) : cheque,
      card: method == PaymentMethod.card ? card.adding(amount) : card,
      free: free,
    ),
    FreeCalendar() => DonationTotals(
      cash: cash,
      cheque: cheque,
      card: card,
      free: free + 1,
    ),
  };

  DonationTotals operator +(DonationTotals other) => DonationTotals(
    cash: cash + other.cash,
    cheque: cheque + other.cheque,
    card: card + other.card,
    free: free + other.free,
  );

  @override
  bool operator ==(Object other) =>
      other is DonationTotals &&
      other.cash == cash &&
      other.cheque == cheque &&
      other.card == card &&
      other.free == free;

  @override
  int get hashCode => Object.hash(cash, cheque, card, free);

  @override
  String toString() =>
      'DonationTotals(cash: $cash, cheque: $cheque, card: $card, free: $free)';
}
