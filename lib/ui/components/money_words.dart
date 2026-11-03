import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

// The French words of the tournées' money (PLAN §5.13), shared by the
// status picker, Accueil, the street screen, « Dons de la tournée » and the
// « Bilan ».

/// [cents] in euros, as the screens show money: « 10 € » for whole euros,
/// « 7,50 € » with cents, « 1 280 € » past a thousand.
String eurosText(AppLocalizations l10n, int cents) {
  final euros = cents ~/ 100;
  final rest = cents % 100;
  return rest == 0
      ? l10n.amountEuros(euros)
      : l10n.amountEurosCents(euros, _twoDigits(rest));
}

/// [amount] as « Montant » shows it, ready to change: « 20 », « 7,50 ».
String amountInputText(AppLocalizations l10n, Amount amount) {
  final euros = amount.cents ~/ 100;
  final rest = amount.cents % 100;
  return rest == 0 ? '$euros' : l10n.amountInputCents(euros, _twoDigits(rest));
}

String _twoDigits(int value) => '$value'.padLeft(2, '0');

/// The paid dons of [totals] and their money: « 19 dons · 280 € ».
String roundTotalsText(AppLocalizations l10n, DonationTotals totals) =>
    l10n.roundTotals(totals.count, eurosText(l10n, totals.cents));

/// How long a tournée has been on: « En tournée depuis 1 h 20 », « … 2 h »,
/// « … 20 min », « … moins d'une minute ».
String roundSinceText(AppLocalizations l10n, Duration elapsed) {
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes % 60;
  if (hours == 0) {
    return minutes == 0
        ? l10n.roundSinceJustStarted
        : l10n.roundSinceMinutes(minutes);
  }
  return minutes == 0
      ? l10n.roundSinceWholeHours(hours)
      : l10n.roundSinceHours(hours, _twoDigits(minutes));
}

/// The time of day of [at], as French writes it: « 14 h 05 », « 18 h ».
String clockTimeText(AppLocalizations l10n, DateTime at) => at.minute == 0
    ? l10n.clockTimeWhole(at.hour)
    : l10n.clockTime(at.hour, _twoDigits(at.minute));

/// [method] on the choice « Espèces | Chèque | Carte ».
String methodChoiceName(AppLocalizations l10n, PaymentMethod method) =>
    switch (method) {
      PaymentMethod.cash => l10n.paymentCash,
      PaymentMethod.cheque => l10n.paymentCheque,
      PaymentMethod.card => l10n.paymentCard,
    };

/// [method] in « Dons de la tournée »: « Espèces », « Chèque », « Carte
/// bancaire ».
String methodName(AppLocalizations l10n, PaymentMethod method) =>
    switch (method) {
      PaymentMethod.cash => l10n.paymentCash,
      PaymentMethod.cheque => l10n.paymentCheque,
      PaymentMethod.card => l10n.paymentCardLong,
    };

/// [donation] inside a sentence: « 10 € en espèces », « calendrier
/// offert ».
String donationWords(AppLocalizations l10n, Donation donation) =>
    switch (donation) {
      PaidDonation(:final method, :final amount) => l10n.donationPaid(
        eurosText(l10n, amount.cents),
        switch (method) {
          PaymentMethod.cash => l10n.paymentCashWord,
          PaymentMethod.cheque => l10n.paymentChequeWord,
          PaymentMethod.card => l10n.paymentCardWord,
        },
      ),
      FreeCalendar() => l10n.donationFreeWord,
    };

/// Why what « Montant » holds is not an amount, under the field.
String amountFailureText(AppLocalizations l10n, AmountFailure failure) =>
    switch (failure) {
      AmountFailure.empty => l10n.amountEmpty,
      AmountFailure.notValid => l10n.amountNotValid,
      AmountFailure.tooManyDecimals => l10n.amountTooManyDecimals,
      AmountFailure.tooLarge => l10n.amountTooLarge,
    };
