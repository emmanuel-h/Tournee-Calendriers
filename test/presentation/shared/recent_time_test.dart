import 'package:test/test.dart';
import 'package:tournee_calendriers/presentation/shared/recent_time.dart';

void main() {
  // Times on the phone's own clock (`DateTime(…)` is local), so the tests
  // read the same in any time zone.
  final now = DateTime(2026, 11, 2, 10, 30);

  RecentTime ago(Duration elapsed) =>
      RecentTime.of(now.subtract(elapsed), now: now);

  group('RecentTime.of', () {
    test('should say « just now » under a minute', () {
      expect(ago(Duration.zero), const JustNow());
      expect(ago(const Duration(seconds: 59)), const JustNow());
    });

    test('should say « just now » for a time a little ahead of the '
        'phone', () {
      expect(ago(const Duration(seconds: -30)), const JustNow());
    });

    test('should count the minutes from one minute to under an hour', () {
      expect(ago(const Duration(minutes: 1)), const MinutesAgo(1));
      expect(
        ago(const Duration(minutes: 59, seconds: 59)),
        const MinutesAgo(59),
      );
    });

    test('should count the hours from one hour on the same day', () {
      expect(ago(const Duration(hours: 1)), const HoursAgo(1));
      expect(
        RecentTime.of(DateTime(2026, 11, 2), now: now),
        const HoursAgo(10),
      );
    });

    test('should say « yesterday » for the day before, even under an '
        'hour', () {
      final justAfterMidnight = DateTime(2026, 11, 2, 0, 20);

      expect(
        RecentTime.of(DateTime(2026, 11, 1, 23, 59), now: now),
        const Yesterday(),
      );
      expect(RecentTime.of(DateTime(2026, 11, 1), now: now), const Yesterday());
      expect(
        RecentTime.of(DateTime(2026, 11, 1, 23, 50), now: justAfterMidnight),
        const MinutesAgo(30),
      );
      expect(
        RecentTime.of(DateTime(2026, 11, 1, 22), now: justAfterMidnight),
        const Yesterday(),
      );
    });

    test('should give the day before yesterday and earlier', () {
      expect(
        RecentTime.of(DateTime(2026, 10, 31, 23, 59), now: now),
        OnDay(DateTime(2026, 10, 31, 23, 59)),
      );
      expect(
        RecentTime.of(DateTime(2026, 10, 3, 9), now: now),
        OnDay(DateTime(2026, 10, 3, 9)),
      );
    });

    test('should find yesterday across a month', () {
      expect(
        RecentTime.of(
          DateTime(2026, 10, 31, 18),
          now: DateTime(2026, 11, 1, 9),
        ),
        const Yesterday(),
      );
    });

    test('should give the day on the phone\'s clock for a UTC time', () {
      final at = DateTime.utc(2026, 10, 3, 12);

      final day = RecentTime.of(at, now: now) as OnDay;

      expect(day.at, at.toLocal());
      expect(day.at.isUtc, isFalse);
    });
  });

  group('equality', () {
    test('should be equal by kind and value', () {
      expect(const JustNow(), const JustNow());
      expect(const JustNow().hashCode, const JustNow().hashCode);
      expect(const Yesterday(), const Yesterday());
      expect(const Yesterday().hashCode, const Yesterday().hashCode);
      expect(const MinutesAgo(2), const MinutesAgo(2));
      expect(const MinutesAgo(2).hashCode, const MinutesAgo(2).hashCode);
      expect(const MinutesAgo(2), isNot(const MinutesAgo(3)));
      expect(const HoursAgo(2), const HoursAgo(2));
      expect(const HoursAgo(2).hashCode, const HoursAgo(2).hashCode);
      expect(const HoursAgo(2), isNot(const HoursAgo(3)));
      expect(const HoursAgo(2), isNot(const MinutesAgo(2)));
      expect(OnDay(DateTime(2026, 10, 3)), OnDay(DateTime(2026, 10, 3)));
      expect(
        OnDay(DateTime(2026, 10, 3)).hashCode,
        OnDay(DateTime(2026, 10, 3)).hashCode,
      );
      expect(OnDay(DateTime(2026, 10, 3)), isNot(OnDay(DateTime(2026, 10, 4))));
      expect(const JustNow(), isNot(const Yesterday()));
    });

    test('should name itself', () {
      expect('${const JustNow()}', 'JustNow');
      expect('${const Yesterday()}', 'Yesterday');
      expect('${const MinutesAgo(2)}', 'MinutesAgo(2)');
      expect('${const HoursAgo(3)}', 'HoursAgo(3)');
      expect(
        '${OnDay(DateTime(2026, 10, 3))}',
        'OnDay(${DateTime(2026, 10, 3)})',
      );
    });
  });
}
