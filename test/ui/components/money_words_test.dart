import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

import '../../domain/round/round_fixtures.dart';
import '../../support/results.dart';

/// A non-breaking space, and the narrow one French puts between thousands.
const _nbsp = ' ';
const _thin = ' ';

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));

  group('eurosText', () {
    for (final (amount, text) in [
      (1000, '10$_nbsp€'),
      (750, '7,50$_nbsp€'),
      (705, '7,05$_nbsp€'),
      (5, '0,05$_nbsp€'),
      (0, '0$_nbsp€'),
      (128000, '1${_thin}280$_nbsp€'),
      (100099, '1${_thin}000,99$_nbsp€'),
    ]) {
      test('should write $amount cents « $text »', () {
        expect(eurosText(l10n, amount), text);
      });
    }
  });

  group('amountInputText', () {
    for (final (amount, text) in [
      (2000, '20'),
      (750, '7,50'),
      (1, '0,01'),
      (100000, '1000'),
    ]) {
      test('should prefill « $text » for $amount cents', () {
        expect(amountInputText(l10n, cents(amount)), text);
      });
    }

    test('should give back what Amount.parse reads', () {
      for (final amount in [1, 99, 100, 750, 100000]) {
        expect(
          valueOf(Amount.parse(amountInputText(l10n, cents(amount)))),
          cents(amount),
        );
      }
    });
  });

  group('roundTotalsText', () {
    test('should count the paid dons and their money', () {
      expect(
        roundTotalsText(
          l10n,
          DonationTotals.of([cash(1000), cheque(2000), offered]),
        ),
        '2${_nbsp}dons · 30$_nbsp€',
      );
    });

    test('should say « 1 don »', () {
      expect(
        roundTotalsText(l10n, DonationTotals.of([card(1000)])),
        '1${_nbsp}don · 10$_nbsp€',
      );
    });

    test('should say « 0 don · 0 € » when none is paid', () {
      expect(
        roundTotalsText(l10n, DonationTotals.of([offered])),
        '0${_nbsp}don · 0$_nbsp€',
      );
    });
  });

  group('roundSinceText', () {
    for (final (elapsed, text) in [
      (Duration.zero, "En tournée depuis moins d'une minute"),
      (const Duration(seconds: 59), "En tournée depuis moins d'une minute"),
      (const Duration(minutes: 1), 'En tournée depuis 1${_nbsp}min'),
      (const Duration(minutes: 59), 'En tournée depuis 59${_nbsp}min'),
      (const Duration(minutes: 60), 'En tournée depuis 1${_nbsp}h'),
      (const Duration(minutes: 61), 'En tournée depuis 1${_nbsp}h${_nbsp}01'),
      (
        const Duration(hours: 1, minutes: 20),
        'En tournée depuis 1${_nbsp}h${_nbsp}20',
      ),
      (const Duration(hours: 2), 'En tournée depuis 2${_nbsp}h'),
      (
        const Duration(hours: 12, minutes: 5),
        'En tournée depuis 12${_nbsp}h${_nbsp}05',
      ),
    ]) {
      test('should say « $text » after $elapsed', () {
        expect(roundSinceText(l10n, elapsed), text);
      });
    }
  });

  group('clockTimeText', () {
    test('should write the minutes with two digits', () {
      expect(
        clockTimeText(l10n, DateTime(2026, 10, 24, 14, 5)),
        '14${_nbsp}h${_nbsp}05',
      );
    });

    test('should write the hour alone on the hour', () {
      expect(clockTimeText(l10n, DateTime(2026, 10, 24, 18)), '18${_nbsp}h');
    });

    test('should write one minute past', () {
      expect(
        clockTimeText(l10n, DateTime(2026, 10, 24, 9, 1)),
        '9${_nbsp}h${_nbsp}01',
      );
    });
  });

  group('payment methods', () {
    for (final (method, choice, name) in [
      (PaymentMethod.cash, 'Espèces', 'Espèces'),
      (PaymentMethod.cheque, 'Chèque', 'Chèque'),
      (PaymentMethod.card, 'Carte', 'Carte bancaire'),
    ]) {
      test('should name $method « $choice » on the choice and « $name » in '
          'the list', () {
        expect(methodChoiceName(l10n, method), choice);
        expect(methodName(l10n, method), name);
      });
    }
  });

  group('donationWords', () {
    for (final (donation, text) in [
      (cash(1000), '10$_nbsp€ en espèces'),
      (cheque(500), '5$_nbsp€ en chèque'),
      (card(750), '7,50$_nbsp€ en carte'),
      (offered, 'calendrier offert'),
    ]) {
      test('should say « $text »', () {
        expect(donationWords(l10n, donation), text);
      });
    }
  });

  group('amountFailureText', () {
    for (final (failure, text) in [
      (AmountFailure.empty, 'Écrivez un montant.'),
      (AmountFailure.notValid, 'Entrez un montant valide.'),
      (
        AmountFailure.tooManyDecimals,
        'Deux chiffres après la virgule au plus.',
      ),
      (AmountFailure.tooLarge, '1${_nbsp}000$_nbsp€ au plus par don.'),
    ]) {
      test('should say « $text » for $failure', () {
        expect(amountFailureText(l10n, failure), text);
      });
    }
  });
}
