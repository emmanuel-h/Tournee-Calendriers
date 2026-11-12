import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/shared/calendar_day.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

/// Where a tap on a reminder leads (PLAN §5.17).
///
/// `sealed`: whoever opens it handles each case.
sealed class ReminderTarget {
  const ReminderTarget();
}

/// The street at the house (or the building's grid at the door) of
/// [place].
final class OpenComeBackPlace extends ReminderTarget {
  const OpenComeBackPlace(this.place);

  final ComeBackPlace place;

  @override
  bool operator ==(Object other) =>
      other is OpenComeBackPlace && other.place == place;

  @override
  int get hashCode => place.hashCode;

  @override
  String toString() => 'OpenComeBackPlace($place)';
}

/// « À repasser », the whole list.
final class OpenComeBackList extends ReminderTarget {
  const OpenComeBackList();

  @override
  bool operator ==(Object other) => other is OpenComeBackList;

  @override
  int get hashCode => (OpenComeBackList).hashCode;

  @override
  String toString() => 'OpenComeBackList';
}

/// A local notification to show at [at] (PLAN §5.17). `sealed`: the
/// wording of each kind differs.
sealed class Reminder {
  const Reminder(this.at);

  /// When it rings, in the phone's time zone: the day and hour of a
  /// « repasser » are those of the phone's calendar and clock.
  final DateTime at;

  /// Where a tap on it leads.
  ReminderTarget get target;

  /// The « repasser » it reminds of, by address; never empty.
  List<ComeBackEntry> get entries;
}

/// « Repasser vers 19 h · 12 Rue Nationale », [ReminderPlan.ahead] before
/// the hour of [entry].
final class HourReminder extends Reminder {
  const HourReminder(super.at, this.entry);

  final ComeBackEntry entry;

  /// The hour to come back (« vers 19 h »): [ReminderPlan] makes an hour
  /// reminder only for a « repasser » with one.
  int get hour => entry.comeBack.hour!;

  @override
  List<ComeBackEntry> get entries => [entry];

  @override
  ReminderTarget get target => OpenComeBackPlace(entry.place);

  @override
  bool operator ==(Object other) =>
      other is HourReminder && other.at == at && other.entry == entry;

  @override
  int get hashCode => Object.hash(at, entry);

  @override
  String toString() => 'HourReminder($at, $entry)';
}

/// « 3 maisons à repasser aujourd'hui », at [ReminderPlan.dayHour] on
/// [day], for every [entries] of that day without an hour.
final class DayReminder extends Reminder {
  DayReminder(super.at, this.day, Iterable<ComeBackEntry> entries)
    : entries = List.unmodifiable(entries);

  final CalendarDay day;

  @override
  final List<ComeBackEntry> entries;

  /// The house itself when it is the only one, else the list.
  @override
  ReminderTarget get target => switch (entries) {
    [final only] => OpenComeBackPlace(only.place),
    _ => const OpenComeBackList(),
  };

  @override
  bool operator ==(Object other) =>
      other is DayReminder &&
      other.at == at &&
      other.day == day &&
      sameItems(other.entries, entries);

  @override
  int get hashCode => Object.hash(at, day, Object.hashAll(entries));

  @override
  String toString() => 'DayReminder($at, $day, $entries)';
}

/// The reminders one member's phone rings for the « repasser » of the
/// open secteur (PLAN §5.17), a domain service worked out again each time
/// the streets change:
///
/// - only the « repasser » the member set (the last change is theirs); a
///   teammate's shows in the list only;
/// - with an hour: one [HourReminder], [ahead] before it;
/// - a day without an hour: one [DayReminder] at [dayHour] that day, for
///   all of them;
/// - never for a time already gone, nor for a « repasser » with no day.
final class ReminderPlan {
  ReminderPlan._(Iterable<Reminder> reminders)
    : reminders = List.unmodifiable(reminders);

  /// No reminder at all: the switch « Rappels pour repasser » is off.
  static final none = ReminderPlan._(const []);

  /// How long before the hour a reminder rings.
  static const ahead = Duration(minutes: 15);

  /// The hour of the reminder of a day without an hour: early enough to
  /// plan the day, late enough not to wake anyone.
  static const dayHour = 9;

  /// The reminders of [entries] for [member], seen at [now] (an instant,
  /// as the `Clock` gives it).
  factory ReminderPlan.of(
    Iterable<ComeBackEntry> entries, {
    required MemberId member,
    required DateTime now,
  }) {
    final reminders = <Reminder>[];
    final withoutHour = <CalendarDay, List<ComeBackEntry>>{};
    for (final entry in entries) {
      if (!entry.isSetBy(member)) continue;
      final ComeBackEntry(:comeBack) = entry;
      switch ((comeBack.day, comeBack.hour)) {
        case (final day?, final hour?):
          final at = _at(day, hour).subtract(ahead);
          if (at.isAfter(now)) reminders.add(HourReminder(at, entry));
        case (final day?, null):
          (withoutHour[day] ??= []).add(entry);
        case (null, _):
          break;
      }
    }
    for (final MapEntry(key: day, value: entries) in withoutHour.entries) {
      final at = _at(day, dayHour);
      if (at.isAfter(now)) {
        reminders.add(
          DayReminder(at, day, entries..sort(ComeBackEntry.byAddress)),
        );
      }
    }
    return ReminderPlan._(reminders..sort(_byTime));
  }

  /// In the order they ring; at the same time (two houses at the same
  /// hour), by address, so the order never depends on the sort.
  final List<Reminder> reminders;

  /// Whether a reminder rings for [place] (« rappel prévu »).
  bool rings(ComeBackPlace place) => reminders.any(
    (reminder) => reminder.entries.any((entry) => entry.place == place),
  );

  /// [hour] o'clock on [day], on the phone's clock (`DateTime` without
  /// `.utc` is local time; it handles the change to summer time).
  static DateTime _at(CalendarDay day, int hour) =>
      DateTime(day.year, day.month, day.day, hour);

  static int _byTime(Reminder a, Reminder b) {
    final byTime = a.at.compareTo(b.at);
    if (byTime != 0) return byTime;
    return ComeBackEntry.byAddress(a.entries.first, b.entries.first);
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderPlan && sameItems(other.reminders, reminders);

  @override
  int get hashCode => Object.hashAll(reminders);

  @override
  String toString() => 'ReminderPlan($reminders)';
}
