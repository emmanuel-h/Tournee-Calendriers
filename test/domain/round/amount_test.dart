import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/amount.dart';

import '../../support/results.dart';

void main() {
  group('create', () {
    test('should keep the cents when within 0,01 € and 1 000 €', () {
      expect(valueOf(Amount.create(1)).cents, 1);
      expect(valueOf(Amount.create(750)).cents, 750);
      expect(valueOf(Amount.create(100000)).cents, 100000);
    });

    test('should refuse no money at all', () {
      expect(failureOf(Amount.create(0)), AmountFailure.notValid);
      expect(failureOf(Amount.create(-1)), AmountFailure.notValid);
    });

    test('should refuse one cent past 1 000 €', () {
      expect(failureOf(Amount.create(100001)), AmountFailure.tooLarge);
    });
  });

  group('parse', () {
    test('should read euros with a comma or a dot', () {
      expect(valueOf(Amount.parse('7,50')).cents, 750);
      expect(valueOf(Amount.parse('7.5')).cents, 750);
      expect(valueOf(Amount.parse('7')).cents, 700);
      expect(valueOf(Amount.parse('0,01')).cents, 1);
    });

    test('should read a separator with nothing on one side', () {
      expect(valueOf(Amount.parse('7,')).cents, 700);
      expect(valueOf(Amount.parse(',5')).cents, 50);
    });

    test('should ignore spaces, the thousands one included', () {
      expect(valueOf(Amount.parse(' 1 000 ')).cents, 100000);
      expect(valueOf(Amount.parse('1 000')).cents, 100000);
    });

    test('should ignore leading zeros', () {
      expect(valueOf(Amount.parse('0001000')).cents, 100000);
    });

    test('should ask for an amount when the field is empty', () {
      expect(failureOf(Amount.parse('')), AmountFailure.empty);
      expect(failureOf(Amount.parse('   ')), AmountFailure.empty);
    });

    test('should refuse what is not a number', () {
      for (final text in ['abc', '7,5,0', '-5', '+5', ',', '7 €', '1e3']) {
        expect(
          failureOf(Amount.parse(text)),
          AmountFailure.notValid,
          reason: text,
        );
      }
    });

    test('should refuse zero', () {
      expect(failureOf(Amount.parse('0')), AmountFailure.notValid);
      expect(failureOf(Amount.parse('0,00')), AmountFailure.notValid);
    });

    test('should refuse a third digit after the comma', () {
      expect(failureOf(Amount.parse('7,505')), AmountFailure.tooManyDecimals);
      expect(failureOf(Amount.parse('7,500')), AmountFailure.tooManyDecimals);
      expect(valueOf(Amount.parse('7,05')).cents, 705);
    });

    test('should refuse more than 1 000 €', () {
      expect(failureOf(Amount.parse('1000,01')), AmountFailure.tooLarge);
      expect(failureOf(Amount.parse('10000')), AmountFailure.tooLarge);
      expect(
        failureOf(Amount.parse('99999999999999999999999')),
        AmountFailure.tooLarge,
      );
      expect(valueOf(Amount.parse('1000,00')).cents, 100000);
      expect(valueOf(Amount.parse('999,99')).cents, 99999);
    });
  });

  test('should be equal to an amount of the same cents', () {
    expect(valueOf(Amount.create(750)), valueOf(Amount.parse('7,5')));
    expect(
      valueOf(Amount.create(750)).hashCode,
      valueOf(Amount.create(750)).hashCode,
    );
    expect(valueOf(Amount.create(750)), isNot(valueOf(Amount.create(751))));
    expect(valueOf(Amount.create(750)).toString(), 'Amount(750)');
  });
}
