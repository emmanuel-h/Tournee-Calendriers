import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// Why a number cannot be a count of [Calendars].
enum CalendarsFailure {
  /// Below 0 or above [Calendars.max].
  outOfRange,
}

/// How many calendars a house (or a door) marked ✓ took (#114, PLAN §6.1):
/// 1 when it becomes ✓, one more with each « + Ajouter un don », one less
/// with « − ». A count only: no amount, no payment method, which stay in
/// the tournée's dons (PLAN §8.3).
///
/// The count follows the status (see [keptBy]): a house that is not ✓
/// took none, a ✓ house took at least one. So stored data without a count
/// (written before #114) reads as 1 on a ✓ and 0 otherwise.
final class Calendars {
  const Calendars._(this.count);

  /// No calendar: the house is not ✓.
  static const none = Calendars._(0);

  /// The calendar a house takes when it becomes ✓.
  static const one = Calendars._(1);

  /// The highest count: « 99 » still fits in the badge of a tile, and the
  /// security rules refuse anything higher (PLAN §8.2).
  static const max = 99;

  /// The count [count], or [CalendarsFailure.outOfRange] when it is below 0
  /// or above [max].
  static Result<Calendars, CalendarsFailure> create(int count) =>
      count < 0 || count > max
      ? const Err(CalendarsFailure.outOfRange)
      : Ok(Calendars._(count));

  /// The calendars a house or door with [status] keeps of [calendars]:
  /// - done: at least one, a ✓ meaning a calendar was handed over;
  /// - any other status: none, the count goes with the ✓.
  ///
  /// The `House` and `Dwelling` factories run it, as they do
  /// `NobodyHomeTries.keptBy`, so nothing can build a house that breaks it.
  static Calendars keptBy(VisitStatus status, Calendars calendars) =>
      switch (status) {
        VisitStatus.done => calendars.count == 0 ? one : calendars,
        VisitStatus.toDo ||
        VisitStatus.refused ||
        VisitStatus.nobodyHome ||
        VisitStatus.comeBack => none,
      };

  /// The number of calendars, 0 to [max].
  final int count;

  /// One calendar more (« + Ajouter un don »); null at [max].
  Calendars? get more => count < max ? Calendars._(count + 1) : null;

  /// One calendar less (« − »); null at one or none: a ✓ took at least one.
  Calendars? get fewer => count > 1 ? Calendars._(count - 1) : null;

  @override
  bool operator ==(Object other) => other is Calendars && other.count == count;

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => 'Calendars($count)';
}
