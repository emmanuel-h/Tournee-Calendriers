import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why a year, a month and a day are not a [CalendarDay].
enum CalendarDayFailure {
  /// No such date (« 31 novembre »), or a year outside 2000–2999.
  noSuchDay,
}

/// A day of the calendar (« samedi 24 octobre 2026 »), with no time and no
/// time zone: the day a team means when it says « repasser samedi »
/// (PLAN §6.1, `ComeBack`).
///
/// A `DateTime` is an instant; the same instant is Saturday in Paris and
/// already Sunday in Nouméa. A `CalendarDay` is the date itself, so two
/// phones agree on it whatever their clocks say.
final class CalendarDay {
  const CalendarDay._(this.year, this.month, this.day);

  /// The day [day] of [month] of [year], or [CalendarDayFailure.noSuchDay]
  /// when there is none (« 30 février ») or the year is not 2000–2999:
  /// stored data no app writes.
  static Result<CalendarDay, CalendarDayFailure> create(
    int year,
    int month,
    int day,
  ) {
    // `DateTime.utc` rolls an impossible date over (31 November is 1st
    // December): the date exists when nothing rolled over.
    final rolled = DateTime.utc(year, month, day);
    if (year < 2000 ||
        year > 2999 ||
        rolled.year != year ||
        rolled.month != month ||
        rolled.day != day) {
      return const Err(CalendarDayFailure.noSuchDay);
    }
    return Ok(CalendarDay._(year, month, day));
  }

  /// The calendar day of [time] as [time] reads it: a local time gives the
  /// phone's day, a UTC time the day in UTC. The caller chooses (the
  /// screens give the phone's local time, PLAN §5.7).
  factory CalendarDay.of(DateTime time) =>
      CalendarDay._(time.year, time.month, time.day);

  final int year;

  /// 1 (January) to 12.
  final int month;

  /// 1 to 31.
  final int day;

  /// Counted in UTC, which has no change of summer time: every day there
  /// is 24 hours long, so whole days add and subtract exactly.
  DateTime get _utc => DateTime.utc(year, month, day);

  /// The day [days] later (earlier when negative).
  CalendarDay plusDays(int days) =>
      CalendarDay.of(DateTime.utc(year, month, day + days));

  /// How many days [other] is before this day; negative when it is after.
  int daysSince(CalendarDay other) => _utc.difference(other._utc).inDays;

  /// The day of the week, as `DateTime` counts it: 1 for Monday to 7 for
  /// Sunday.
  int get weekday => _utc.weekday;

  /// Midnight at the start of this day, in the phone's time zone: what the
  /// screens hand to the French date formats.
  DateTime toDateTime() => DateTime(year, month, day);

  @override
  bool operator ==(Object other) =>
      other is CalendarDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// `2026-10-24`.
  @override
  String toString() =>
      '$year-${'$month'.padLeft(2, '0')}-${'$day'.padLeft(2, '0')}';
}
