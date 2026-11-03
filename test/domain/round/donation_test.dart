import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';

import 'round_fixtures.dart';

void main() {
  test('should hold the method and the amount of a paid don', () {
    final don = cash(1000);

    expect(don, isA<PaidDonation>());
    final paid = don as PaidDonation;
    expect(paid.method, PaymentMethod.cash);
    expect(paid.amount, cents(1000));
  });

  test('should equal a don of the same method and amount only', () {
    expect(cash(1000), cash(1000));
    expect(cash(1000).hashCode, cash(1000).hashCode);
    expect(cash(1000), isNot(cheque(1000)));
    expect(cash(1000), isNot(cash(1001)));
    expect(cash(1000).toString(), 'PaidDonation(cash, 1000)');
  });

  test('should make every free calendar equal', () {
    // Built at run time: a `const` one would never run the constructor.
    // ignore: prefer_const_constructors
    final free = Donation.free();

    expect(free, offered);
    expect(free.hashCode, offered.hashCode);
    expect(free, isNot(cash(1)));
    expect(free.toString(), 'FreeCalendar');
  });
}
