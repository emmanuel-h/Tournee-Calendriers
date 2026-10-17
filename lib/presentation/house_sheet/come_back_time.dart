import 'package:tournee_calendriers/domain/shared/calendar_day.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';

// What « Quand repasser ? » shows (PLAN §5.7, mockup HouseComeBack, #81):
// the day chips, the hour, and the line that says it in words. Plain data,
// tested without widgets; the sheet only words it in French.

/// How a day stands from today, which decides its words: « Aujourd'hui »,
/// « Demain », « Hier », or its date (« Sam. 24 », « Le samedi 24 oct. »,
/// « C'était le mercredi 14 oct. »).
///
/// An `enum`: the sheet's `switch` over it must handle every case.
enum DayFromToday {
  /// Before yesterday: past, said with its date.
  earlier,

  /// The day before today: past.
  yesterday,

  today,
  tomorrow,

  /// After tomorrow: said with its date.
  later;

  /// How [day] stands from [today].
  static DayFromToday of(CalendarDay day, {required CalendarDay today}) =>
      switch (day.daysSince(today)) {
        < -1 => earlier,
        -1 => yesterday,
        0 => DayFromToday.today,
        1 => tomorrow,
        _ => later,
      };

  /// Whether the day is gone: the summary line says « C'était… ».
  bool get isPast => this == earlier || this == yesterday;
}

/// One day of « Quand repasser ? »: a chip, or the chosen day of the
/// summary line.
final class ComeBackDay {
  const ComeBackDay(this.day, this.fromToday);

  final CalendarDay day;
  final DayFromToday fromToday;

  @override
  bool operator ==(Object other) =>
      other is ComeBackDay && other.day == day && other.fromToday == fromToday;

  @override
  int get hashCode => Object.hash(day, fromToday);

  @override
  String toString() => 'ComeBackDay($day, ${fromToday.name})';
}

/// « Quand repasser ? » of one sheet: the [days] to choose from, the
/// [chosen] one, its [hour], and the [hours] offered.
final class ComeBackTime {
  const ComeBackTime._({
    required this.days,
    required this.chosen,
    required this.hour,
  });

  /// The chips offered from today: today, tomorrow, then the next days, a
  /// week in all. Enough for « repassez samedi » or « la semaine
  /// prochaine », short enough to see at a glance on a street (the row
  /// scrolls sideways).
  static const dayCount = 7;

  /// What the sheet shows for [comeBack] (null: no « repasser », the block
  /// greyed with nothing chosen), seen on [today], the phone's calendar
  /// day.
  ///
  /// A chosen day outside the week offered (set for yesterday, or by a
  /// teammate for later) gets its own chip, in date order, so the choice
  /// is always visible and can be undone.
  factory ComeBackTime.of(ComeBack? comeBack, {required CalendarDay today}) {
    ComeBackDay dayOf(CalendarDay day) =>
        ComeBackDay(day, DayFromToday.of(day, today: today));
    final offered = [
      for (var offset = 0; offset < dayCount; offset++) today.plusDays(offset),
    ];
    final chosenDay = comeBack?.day;
    final days = [
      if (chosenDay != null && chosenDay.daysSince(today) < 0) chosenDay,
      ...offered,
      if (chosenDay != null && chosenDay.daysSince(today) >= dayCount)
        chosenDay,
    ];
    return ComeBackTime._(
      days: List.unmodifiable(days.map(dayOf)),
      chosen: chosenDay == null ? null : dayOf(chosenDay),
      hour: comeBack?.hour,
    );
  }

  /// The day chips, in date order.
  final List<ComeBackDay> days;

  /// The day chosen; null when none is (no time set).
  final ComeBackDay? chosen;

  /// The hour chosen; null for « Pas d'heure ».
  final int? hour;

  /// The hours of the list, after « Pas d'heure »: 8 h to 21 h.
  List<int> get hours => ComeBack.hours;
}
