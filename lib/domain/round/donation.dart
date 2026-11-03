import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';

/// One don of a tournée (PLAN §5.13): money paid with a method, or a
/// calendar given for free (« Calendrier offert »).
///
/// **No house and no time**, on purpose (PLAN §8.3): nothing ties money to
/// an address, not even on the phone.
///
/// `sealed`: a don is one of the two classes below, so a `switch` shows
/// « 10 € · Espèces » or « Calendrier offert » and forgets neither. The
/// factory constructors read as the plan says: `Donation.paid(…)`,
/// `Donation.free()`.
sealed class Donation {
  const Donation();

  /// [amount] paid by [method].
  const factory Donation.paid(PaymentMethod method, Amount amount) =
      PaidDonation;

  /// « Calendrier offert »: a calendar given, no money.
  const factory Donation.free() = FreeCalendar;
}

/// [amount] paid by [method] (« 10 € · Espèces »).
final class PaidDonation extends Donation {
  const PaidDonation(this.method, this.amount);

  final PaymentMethod method;
  final Amount amount;

  @override
  bool operator ==(Object other) =>
      other is PaidDonation && other.method == method && other.amount == amount;

  @override
  int get hashCode => Object.hash(method, amount);

  @override
  String toString() => 'PaidDonation(${method.name}, ${amount.cents})';
}

/// « Calendrier offert ».
final class FreeCalendar extends Donation {
  const FreeCalendar();

  @override
  bool operator ==(Object other) => other is FreeCalendar;

  @override
  int get hashCode => (FreeCalendar).hashCode;

  @override
  String toString() => 'FreeCalendar';
}
