// How a « repasser » time is stored, in Firestore (`comeBack`, PLAN §6.2)
// and in the phone's files (§6.3) alike: one short text.
//
//   ""                 « repasser » with no time set
//   "2026-10-24"       on that day, « Pas d'heure »
//   "2026-10-24T18"    on that day, at about 18 h
//
// A text rather than a map, so a field that held the free hint of before
// #81 (« après 19h ») keeps its type, and the security rules check it with
// one pattern (PLAN §8.2). Pure functions, tested alone.
import 'package:tournee_calendriers/domain/shared/calendar_day.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';

/// The stored text of [comeBack].
String comeBackText(ComeBack comeBack) =>
    switch ((comeBack.day, comeBack.hour)) {
      (null, _) => '',
      (final day?, null) => '$day',
      (final day?, final hour?) => '${day}T${'$hour'.padLeft(2, '0')}',
    };

/// `2026-10-24`, then `T18` optionally.
final _stored = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}))?$');

/// The « repasser » stored as [text].
///
/// Tolerant on purpose: anything that is not a time this code writes
/// reads as « repasser » with no time set. That is the free hint of an
/// older app (« après 19h », before #81), which no screen can show any
/// more and which is dropped when the house is next written; it would be
/// wrong to make a whole street unreadable for it.
ComeBack comeBackFrom(String text) {
  final match = _stored.firstMatch(text);
  if (match == null) return ComeBack.withoutTime;
  final [year, month, date] = [
    for (final group in [1, 2, 3]) int.parse(match.group(group)!),
  ];
  final hour = match.group(4);
  final stored = switch (CalendarDay.create(year, month, date)) {
    Ok(value: final day) => ComeBack.create(
      day: day,
      hour: hour == null ? null : int.parse(hour),
    ),
    Err() => null,
  };
  return switch (stored) {
    Ok(:final value) => value,
    // No such day (« 2026-02-30 »), or an hour the app never offers:
    // damaged, read as no time.
    Err() || null => ComeBack.withoutTime,
  };
}
