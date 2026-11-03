import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';

import '../../domain/round/round_fixtures.dart';

void main() {
  final start = DateTime(2026, 10, 24, 14, 5);
  final now = DateTime(2026, 10, 24, 18, 20);

  RoundOn roundOn({
    DateTime? startedAt,
    DateTime? at,
    int housesVisited = 3,
    List<DonationRow>? donations,
  }) {
    final rows =
        donations ??
        [
          DonationRow(index: 1, donation: cheque(2000)),
          DonationRow(index: 0, donation: cash(1000)),
        ];
    return RoundOn(
      startedAt: startedAt ?? start,
      now: at ?? now,
      housesVisited: housesVisited,
      totals: DonationTotals.of([for (final row in rows) row.donation]),
      donations: rows,
    );
  }

  group('RoundLoading', () {
    test('should equal another', () {
      expect(const RoundLoading(), const RoundLoading());
      expect(const RoundLoading().hashCode, const RoundLoading().hashCode);
      expect(const RoundLoading(), isNot(const RoundOff(canStart: false)));
      expect(const RoundLoading().toString(), 'RoundLoading');
    });
  });

  group('RoundOff', () {
    test('should be equal by whether a tournée can start', () {
      expect(const RoundOff(canStart: true), const RoundOff(canStart: true));
      expect(
        const RoundOff(canStart: true).hashCode,
        const RoundOff(canStart: true).hashCode,
      );
      expect(
        const RoundOff(canStart: true),
        isNot(const RoundOff(canStart: false)),
      );
      expect(
        const RoundOff(canStart: true).toString(),
        'RoundOff(canStart: true)',
      );
    });
  });

  group('DonationRow', () {
    test('should be equal by place and don', () {
      final row = DonationRow(index: 2, donation: cash(500));
      expect(row, DonationRow(index: 2, donation: cash(500)));
      expect(row.hashCode, DonationRow(index: 2, donation: cash(500)).hashCode);
      expect(row, isNot(DonationRow(index: 1, donation: cash(500))));
      expect(row, isNot(DonationRow(index: 2, donation: card(500))));
      expect(row.toString(), 'DonationRow(2, PaidDonation(cash, 500))');
    });
  });

  group('RoundOn', () {
    test('should be equal by every field', () {
      expect(roundOn(), roundOn());
      expect(roundOn().hashCode, roundOn().hashCode);
      expect(roundOn(), isNot(roundOn(startedAt: now)));
      expect(roundOn(), isNot(roundOn(at: start)));
      expect(roundOn(), isNot(roundOn(housesVisited: 4)));
      expect(
        roundOn(),
        isNot(
          roundOn(donations: [DonationRow(index: 0, donation: cash(1000))]),
        ),
      );
    });

    test('should differ by its totals', () {
      final other = RoundOn(
        startedAt: start,
        now: now,
        housesVisited: 3,
        totals: DonationTotals.none,
        donations: roundOn().donations,
      );

      expect(roundOn(), isNot(other));
    });

    test('should not let its dons be changed', () {
      expect(
        () => roundOn().donations.add(
          const DonationRow(index: 9, donation: offered),
        ),
        throwsUnsupportedError,
      );
    });

    test('should say how long it has been on', () {
      expect(roundOn().elapsed, const Duration(hours: 4, minutes: 15));
      expect(roundOn(at: start).elapsed, Duration.zero);
    });

    test('should never be on for less than nothing', () {
      expect(
        roundOn(at: start.subtract(const Duration(seconds: 1))).elapsed,
        Duration.zero,
      );
    });

    test('should name its fields when printed', () {
      expect(roundOn().toString(), startsWith('RoundOn($start, $now, 3, '));
    });
  });
}
