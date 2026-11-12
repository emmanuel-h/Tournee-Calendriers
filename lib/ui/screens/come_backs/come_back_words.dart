import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';
import 'package:tournee_calendriers/presentation/come_backs/come_backs_view.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/ui/components/come_back_time_picker.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

// The French words of « À repasser » and of the reminders (PLAN §5.17):
// the view states and the domain decide what to say, these functions only
// word it.

/// [text] with its first letter in lower case, to sit inside a sentence:
/// « Prochain : aujourd'hui vers 19 h », « repasser le samedi 24 oct. ».
String lowerFirst(String text) =>
    text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);

/// « 12 Rue Nationale », or « Porte 51 · 8 Rue Pasteur » for a door.
String comeBackAddress(
  AppLocalizations l10n, {
  required String number,
  required String street,
  String? door,
}) => switch (door) {
  final door? => l10n.comeBackDoorAddress(door, number, street),
  null => l10n.comeBackAddress(number, street),
};

/// The address of [row].
String comeBackRowAddress(AppLocalizations l10n, ComeBackRow row) =>
    comeBackAddress(
      l10n,
      number: row.number,
      street: row.streetName,
      door: row.door,
    );

/// When [row] is to come back to, with its day; null without one.
String? comeBackRowWhen(AppLocalizations l10n, ComeBackRow row) =>
    switch (row.day) {
      final day? => comeBackWhenText(l10n, day, row.hour),
      null => null,
    };

/// The line under the address of [row]: « par vous », « par vous · pas
/// d'heure », « C'était hier vers 18 h · par Léa »; null when there is
/// nothing to say (nobody known, and no day gone).
String? comeBackRowDetails(AppLocalizations l10n, ComeBackRow row) {
  final parts = [
    if (row.isPast) comeBackRowWhen(l10n, row)!,
    if (row.by case final by?) _byText(l10n, by),
    if (!row.isPast && row.day != null && row.hour == null)
      l10n.comeBackNoHourDetail,
  ];
  return parts.isEmpty
      ? null
      : parts.reduce((first, second) => l10n.comeBackDetails(first, second));
}

/// What a screen reader says for [row]: « Aujourd'hui vers 19 h, 12 Rue
/// Nationale, rappel prévu », « 5 Rue Pasteur, c'était hier vers 18 h ».
String comeBackRowSemantics(AppLocalizations l10n, ComeBackRow row) {
  final address = comeBackRowAddress(l10n, row);
  final when = comeBackRowWhen(l10n, row);
  final text = switch (when) {
    null => address,
    final time when row.isPast => l10n.comeBackRowSemantics(
      address,
      lowerFirst(time),
    ),
    final time => l10n.comeBackRowSemantics(time, address),
  };
  return row.rings ? l10n.comeBackRowRings(text) : text;
}

/// The pill of the street opened at [row]'s house: « N° 12 · repasser
/// aujourd'hui vers 19 h ».
String comeBackRingHint(AppLocalizations l10n, ComeBackRow row) =>
    switch (comeBackRowWhen(l10n, row)) {
      null => l10n.comeBackRingHintAnyTime(row.number),
      final time when row.isPast => l10n.comeBackRingHintPast(
        row.number,
        lowerFirst(time),
      ),
      final time => l10n.comeBackRingHint(row.number, lowerFirst(time)),
    };

String _byText(AppLocalizations l10n, ChangeAuthor by) => switch (by) {
  ChangedByMe() => l10n.comeBackByMe,
  ChangedByMember(:final name) => l10n.comeBackByMember(name),
};

/// The title and text of [reminder]'s notification (ComeBackNotify
/// mockup): « Repasser vers 19 h » over « 12 Rue Nationale »; « 3 maisons
/// à repasser aujourd'hui » over their addresses, one a line. An address
/// and an hour, never a person (PLAN §8.3).
({String title, String body}) reminderText(
  AppLocalizations l10n,
  Reminder reminder,
) => (
  title: switch (reminder) {
    HourReminder(:final hour) => l10n.reminderAtHour(hour),
    DayReminder(:final entries) => l10n.reminderOfDay(entries.length),
  },
  body: [for (final entry in reminder.entries) _entryAddress(l10n, entry)]
      .join('\n'),
);

String _entryAddress(AppLocalizations l10n, ComeBackEntry entry) =>
    comeBackAddress(
      l10n,
      number: entry.place.number.label,
      street: entry.streetName.text,
      door: entry.place.door?.label.text,
    );
