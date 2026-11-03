import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';

import 'round_fixtures.dart';

void main() {
  group('MethodTotal', () {
    test('should count one more don and add its cents', () {
      final total = MethodTotal.none.adding(cents(750)).adding(cents(1000));

      expect(total.count, 2);
      expect(total.cents, 1750);
    });

    test('should add two totals', () {
      final sum =
          MethodTotal(count: 2, cents: 1500) +
          MethodTotal(count: 3, cents: 700);

      expect(sum, MethodTotal(count: 5, cents: 2200));
    });

    test('should refuse a negative count or sum', () {
      expect(() => MethodTotal(count: -1, cents: 0), throwsArgumentError);
      expect(() => MethodTotal(count: 0, cents: -1), throwsArgumentError);
      expect(MethodTotal(count: 0, cents: 0), MethodTotal.none);
    });

    test('should equal a total of the same count and sum only', () {
      final total = MethodTotal(count: 2, cents: 1500);

      expect(total, MethodTotal(count: 2, cents: 1500));
      expect(total.hashCode, MethodTotal(count: 2, cents: 1500).hashCode);
      expect(total, isNot(MethodTotal(count: 3, cents: 1500)));
      expect(total, isNot(MethodTotal(count: 2, cents: 1501)));
      expect(total.toString(), 'MethodTotal(2, 1500)');
    });
  });

  group('DonationTotals', () {
    final totals = DonationTotals.of([
      cash(1000),
      cheque(2000),
      offered,
      cash(750),
      card(500),
      offered,
    ]);

    test('should add up each method apart', () {
      expect(totals.cash, MethodTotal(count: 2, cents: 1750));
      expect(totals.cheque, MethodTotal(count: 1, cents: 2000));
      expect(totals.card, MethodTotal(count: 1, cents: 500));
      expect(totals.of(PaymentMethod.cash), totals.cash);
      expect(totals.of(PaymentMethod.cheque), totals.cheque);
      expect(totals.of(PaymentMethod.card), totals.card);
    });

    test('should count the free calendars apart from the dons', () {
      expect(totals.free, 2);
      expect(totals.count, 4);
      expect(totals.cents, 4250);
    });

    test('should be nothing for no don', () {
      final nothing = DonationTotals.of(const []);

      expect(nothing, DonationTotals.none);
      expect(nothing.count, 0);
      expect(nothing.cents, 0);
      expect(nothing.free, 0);
    });

    test('should add two totals method by method', () {
      final sum = totals + DonationTotals.of([cheque(300), offered]);

      expect(sum.cash, MethodTotal(count: 2, cents: 1750));
      expect(sum.cheque, MethodTotal(count: 2, cents: 2300));
      expect(sum.card, MethodTotal(count: 1, cents: 500));
      expect(sum.free, 3);
    });

    test('should refuse a negative count of free calendars', () {
      expect(
        () => DonationTotals(
          cash: MethodTotal.none,
          cheque: MethodTotal.none,
          card: MethodTotal.none,
          free: -1,
        ),
        throwsArgumentError,
      );
    });

    test('should equal totals of the same values only', () {
      DonationTotals with_({
        int free = 2,
        int cashCents = 1750,
        int chequeCents = 2000,
        int cardCents = 500,
      }) => DonationTotals(
        cash: MethodTotal(count: 2, cents: cashCents),
        cheque: MethodTotal(count: 1, cents: chequeCents),
        card: MethodTotal(count: 1, cents: cardCents),
        free: free,
      );

      expect(totals, with_());
      expect(totals.hashCode, with_().hashCode);
      expect(totals, isNot(with_(free: 3)));
      expect(totals, isNot(with_(cashCents: 1751)));
      expect(totals, isNot(with_(chequeCents: 2001)));
      expect(totals, isNot(with_(cardCents: 501)));
      expect(
        DonationTotals.none.toString(),
        'DonationTotals(cash: MethodTotal(0, 0), cheque: MethodTotal(0, 0), '
        'card: MethodTotal(0, 0), free: 0)',
      );
    });
  });
}
