import 'package:tournee_calendriers/domain/shared/calendar_day.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// Why a day and an hour cannot be the time of a [ComeBack].
enum ComeBackFailure {
  /// An hour was given without a day.
  hourWithoutDay,

  /// The hour is before [ComeBack.firstHour] or after [ComeBack.lastHour].
  hourOutOfRange,
}

/// What goes with a « repasser »: when to come back, a [day] and maybe an
/// [hour] (« Le samedi 24 oct. vers 18 h », PLAN §2, §5.7, #81), or no
/// time at all.
///
/// « Repasser » is a status of its own ([VisitStatus.comeBack]): a house or
/// a door has a `ComeBack` exactly when it has that status (see
/// [ComeBack.keptBy]). A building, which has no status of its own, may
/// carry one for itself (« Repasser » under its grid).
///
/// The time is structured, not free text, so the reminders (#82) can read
/// it, and so nothing about the people living there can be typed in
/// (PLAN §8.3).
final class ComeBack {
  const ComeBack._(this.day, this.hour);

  /// « Repasser » with no time set yet.
  static const withoutTime = ComeBack._(null, null);

  /// The earliest hour offered (« 8 h »): the team calls in the daytime.
  static const firstHour = 8;

  /// The latest hour offered (« 21 h »). The security rules allow the same
  /// hours (PLAN §8.2).
  static const lastHour = 21;

  /// Every hour offered, [firstHour] to [lastHour].
  static List<int> get hours => [
    for (var hour = firstHour; hour <= lastHour; hour++) hour,
  ];

  /// When to come back: on [day], at about [hour] when given; no time at
  /// all when neither is. Refused with [ComeBackFailure.hourWithoutDay]
  /// when there is an hour but no day, with
  /// [ComeBackFailure.hourOutOfRange] for an hour outside [hours].
  ///
  /// Any day is taken, a past one too: a « repasser » set for yesterday is
  /// still what the team was told, the sheet says it is past.
  static Result<ComeBack, ComeBackFailure> create({
    CalendarDay? day,
    int? hour,
  }) {
    if (hour != null) {
      if (day == null) return const Err(ComeBackFailure.hourWithoutDay);
      if (hour < firstHour || hour > lastHour) {
        return const Err(ComeBackFailure.hourOutOfRange);
      }
    }
    return Ok(day == null ? withoutTime : ComeBack._(day, hour));
  }

  /// The come-back a house or a door with [status] keeps of [comeBack]:
  /// only a « repasser » has one, without time unless one is given; any
  /// other status has none. The `House` and `Dwelling` factories run it,
  /// so no house is ever « personne » and « repasser » at once.
  static ComeBack? keptBy(VisitStatus status, ComeBack? comeBack) =>
      status == VisitStatus.comeBack ? comeBack ?? withoutTime : null;

  /// The day to come back; null when no time is set.
  final CalendarDay? day;

  /// The hour, [firstHour] to [lastHour]; null when only the day is set
  /// (« Pas d'heure »), and always null without a [day].
  final int? hour;

  @override
  bool operator ==(Object other) =>
      other is ComeBack && other.day == day && other.hour == hour;

  @override
  int get hashCode => Object.hash(day, hour);

  /// `ComeBack(2026-10-24 18h)`, `ComeBack(2026-10-24)`, `ComeBack()`.
  @override
  String toString() =>
      'ComeBack(${[?day, if (hour case final hour?) '${hour}h'].join(' ')})';
}
