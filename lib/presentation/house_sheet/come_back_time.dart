import 'package:tournee_calendriers/domain/shared/calendar_day.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';

// What « Quand repasser ? » shows (PLAN §5.7, mockup HouseComeBack, #81):
// the day chips and the calendar, the hour, and the line that says it in
// words. Plain data,
// tested without widgets; the sheet only words it in French.

/// How a day stands from today, which decides its words: « Aujourd'hui »,
/// « Demain », « Hier », or its date (« Le samedi 24 oct. », « C'était le
/// mercredi 14 oct. »).
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

/// The chosen day of « Quand repasser ? », with how it stands from today.
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

/// « Quand repasser ? » of one sheet: the two day chips ([today],
/// [tomorrow]), the calendar for any other day, the [chosen] day, its
/// [hour], and the [hours] offered (PLAN §5.7, #82).
final class ComeBackTime {
  const ComeBackTime._({
    required this.today,
    required this.chosen,
    required this.hour,
  });

  /// How far ahead the calendar goes, in days from today: two months
  /// cover any « repassez début décembre » of a round.
  static const calendarDays = 60;

  /// What the sheet shows for [comeBack] (null: no « repasser », the block
  /// greyed with nothing chosen), seen on [today], the phone's calendar
  /// day.
  factory ComeBackTime.of(ComeBack? comeBack, {required CalendarDay today}) =>
      ComeBackTime._(
        today: today,
        chosen: switch (comeBack?.day) {
          final day? => ComeBackDay(day, DayFromToday.of(day, today: today)),
          null => null,
        },
        hour: comeBack?.hour,
      );

  /// The day of the first chip, « Aujourd'hui »; also the first day of the
  /// calendar.
  final CalendarDay today;

  /// The day of the second chip, « Demain ».
  CalendarDay get tomorrow => today.plusDays(1);

  /// The day chosen; null when none is (no time set).
  final ComeBackDay? chosen;

  /// The hour chosen; null for « Pas d'heure ».
  final int? hour;

  /// The chosen day when no chip shows it (picked in the calendar, gone,
  /// or set by a teammate further ahead): the 📅 button is then filled and
  /// names it. Null when no day, today or tomorrow is chosen.
  ComeBackDay? get otherDay => switch (chosen?.fromToday) {
    null || DayFromToday.today || DayFromToday.tomorrow => null,
    DayFromToday.earlier ||
    DayFromToday.yesterday ||
    DayFromToday.later => chosen,
  };

  /// The last day the calendar offers.
  CalendarDay get lastCalendarDay => today.plusDays(calendarDays);

  /// The day the calendar opens on: the chosen day when the calendar
  /// offers it, else the day after tomorrow, the first one no chip has.
  CalendarDay get calendarStart => switch (chosen?.day) {
    final day?
        when day.daysSince(today) >= 0 && lastCalendarDay.daysSince(day) >= 0 =>
      day,
    _ => today.plusDays(2),
  };

  /// The hours of the list, after « Pas d'heure »: 8 h to 21 h.
  List<int> get hours => ComeBack.hours;
}
