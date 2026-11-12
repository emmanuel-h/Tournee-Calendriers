import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/shared/calendar_day.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

/// The « repasser » of one [day], in the order « À repasser » lists them
/// (see [ComeBackAgenda]).
final class ComeBackDayGroup {
  ComeBackDayGroup(this.day, Iterable<ComeBackEntry> entries)
    : entries = List.unmodifiable(entries);

  final CalendarDay day;

  /// Never empty.
  final List<ComeBackEntry> entries;

  @override
  bool operator ==(Object other) =>
      other is ComeBackDayGroup &&
      other.day == day &&
      sameItems(other.entries, entries);

  @override
  int get hashCode => Object.hash(day, Object.hashAll(entries));

  @override
  String toString() => 'ComeBackDayGroup($day, $entries)';
}

/// « À repasser » (PLAN §5.17): every « repasser » of the secteur grouped
/// by day, seen on one day of the phone's calendar.
///
/// - [days]: today and each later day that has some, in date order. Within
///   a day, those with an hour first, by hour, then those without; ties by
///   street name (the French way) and number, then door.
/// - [anyTime] (« À tout moment »), last: those with no day, and those
///   whose day is gone, in the same street and number order.
final class ComeBackAgenda {
  ComeBackAgenda._(
    Iterable<ComeBackDayGroup> days,
    Iterable<ComeBackEntry> anyTime,
  ) : days = List.unmodifiable(days),
      anyTime = List.unmodifiable(anyTime);

  /// The agenda of [entries] seen on [today].
  factory ComeBackAgenda.of(
    Iterable<ComeBackEntry> entries, {
    required CalendarDay today,
  }) {
    final byDay = <CalendarDay, List<ComeBackEntry>>{};
    final anyTime = <ComeBackEntry>[];
    for (final entry in entries) {
      switch (entry.comeBack.day) {
        case final day? when day.daysSince(today) >= 0:
          (byDay[day] ??= []).add(entry);
        case _:
          anyTime.add(entry);
      }
    }
    final days = byDay.keys.toList()..sort((a, b) => a.daysSince(b));
    return ComeBackAgenda._([
      for (final day in days)
        ComeBackDayGroup(day, byDay[day]!..sort(_withinDay)),
    ], anyTime..sort(ComeBackEntry.byAddress));
  }

  final List<ComeBackDayGroup> days;
  final List<ComeBackEntry> anyTime;

  /// How many « repasser » in all: « À repasser (5) ».
  int get count =>
      anyTime.length + days.fold(0, (sum, day) => sum + day.entries.length);

  /// The first « repasser » with a day from today on (« Prochain :
  /// aujourd'hui vers 19 h »); null when none has one.
  ComeBackEntry? get next => days.firstOrNull?.entries.first;

  /// Hours first, by hour; then those without; then by address.
  static int _withinDay(ComeBackEntry a, ComeBackEntry b) {
    final byHour = switch ((a.comeBack.hour, b.comeBack.hour)) {
      (final a?, final b?) => a.compareTo(b),
      (null, null) => 0,
      (null, _) => 1,
      (_, null) => -1,
    };
    return byHour != 0 ? byHour : ComeBackEntry.byAddress(a, b);
  }

  @override
  bool operator ==(Object other) =>
      other is ComeBackAgenda &&
      sameItems(other.days, days) &&
      sameItems(other.anyTime, anyTime);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(days), Object.hashAll(anyTime));

  @override
  String toString() => 'ComeBackAgenda($days, anyTime: $anyTime)';
}
