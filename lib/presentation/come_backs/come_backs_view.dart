import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';

// What « À repasser » and its row on Accueil show (PLAN §5.17, mockups
// HomeComeBack and ComeBackList), as plain data tested without widgets.

/// One « repasser » of the list: « [19 h] 12 Rue Nationale · par vous 🔔 ».
final class ComeBackRow {
  const ComeBackRow({
    required this.place,
    required this.streetName,
    required this.number,
    this.door,
    this.day,
    this.hour,
    this.by,
    this.rings = false,
  });

  /// Where a tap leads: the street at the house, the grid at the door.
  final ComeBackPlace place;

  /// « Rue Nationale ».
  final String streetName;

  /// The house number as its tile shows it (« 12bis »).
  final String number;

  /// The label of the door (« 51 » of « Porte 51 · 8 Rue Pasteur »); null
  /// for a house, or a building's own « Repasser ».
  final String? door;

  /// The day to come back, and how it stands from today; null when none
  /// was set.
  final ComeBackDay? day;

  /// The hour, in the blue square (« 19 h »); null without one.
  final int? hour;

  /// Who set it (« par vous », « par Léa »); null when nobody is known.
  final ChangeAuthor? by;

  /// This phone will ring for it: 🔔, « rappel prévu ».
  final bool rings;

  /// Its day is gone: « C'était hier vers 18 h » under it, no hour in its
  /// square.
  bool get isPast => day?.fromToday.isPast ?? false;

  @override
  bool operator ==(Object other) =>
      other is ComeBackRow &&
      other.place == place &&
      other.streetName == streetName &&
      other.number == number &&
      other.door == door &&
      other.day == day &&
      other.hour == hour &&
      other.by == by &&
      other.rings == rings;

  @override
  int get hashCode =>
      Object.hash(place, streetName, number, door, day, hour, by, rings);

  @override
  String toString() =>
      'ComeBackRow($place, $streetName, $number, $door, $day, $hour, $by, '
      'rings: $rings)';
}

/// The heading of a group of « À repasser ». `sealed`: the screen words
/// each case.
sealed class ComeBackHeading {
  const ComeBackHeading();
}

/// « AUJOURD'HUI », « DEMAIN », « SAMEDI 24 OCT. »: a day from today on.
final class ComeBackOnDay extends ComeBackHeading {
  const ComeBackOnDay(this.day);

  final ComeBackDay day;

  @override
  bool operator ==(Object other) => other is ComeBackOnDay && other.day == day;

  @override
  int get hashCode => day.hashCode;

  @override
  String toString() => 'ComeBackOnDay($day)';
}

/// « À TOUT MOMENT »: no day, or a day gone.
final class ComeBackAnyTime extends ComeBackHeading {
  const ComeBackAnyTime();

  @override
  bool operator ==(Object other) => other is ComeBackAnyTime;

  @override
  int get hashCode => (ComeBackAnyTime).hashCode;

  @override
  String toString() => 'ComeBackAnyTime';
}

/// One group of « À repasser »: its heading and its rows, never empty.
final class ComeBackSection {
  ComeBackSection(this.heading, Iterable<ComeBackRow> rows)
    : rows = List.unmodifiable(rows);

  final ComeBackHeading heading;
  final List<ComeBackRow> rows;

  @override
  bool operator ==(Object other) =>
      other is ComeBackSection &&
      other.heading == heading &&
      sameItems(other.rows, rows);

  @override
  int get hashCode => Object.hash(heading, Object.hashAll(rows));

  @override
  String toString() => 'ComeBackSection($heading, $rows)';
}

/// « À repasser (5) » and its groups; on Accueil, the row « ↻ À repasser
/// (5) › » with « Prochain : aujourd'hui vers 19 h ».
final class ComeBacksView {
  ComeBacksView({
    required this.loading,
    required this.count,
    required this.next,
    required Iterable<ComeBackSection> sections,
  }) : sections = List.unmodifiable(sections);

  /// Before the streets are first read: nothing to show.
  static final reading = ComeBacksView(
    loading: true,
    count: 0,
    next: null,
    sections: const [],
  );

  final bool loading;

  /// How many « repasser » in the secteur.
  final int count;

  /// The first one with a day from today on; null when none has one.
  final ComeBackRow? next;

  /// The days from today in order, then « À tout moment ».
  final List<ComeBackSection> sections;

  /// The row of [place]; null when it is not « repasser » (any more).
  ComeBackRow? rowAt(ComeBackPlace place) {
    for (final section in sections) {
      for (final row in section.rows) {
        if (row.place == place) return row;
      }
    }
    return null;
  }

  /// Accueil shows its row only when there is something to come back to.
  bool get shown => count > 0;

  /// « 🔔 vous recevrez un rappel » under the title, when a row has its 🔔.
  bool get anyRings =>
      sections.any((section) => section.rows.any((row) => row.rings));

  @override
  bool operator ==(Object other) =>
      other is ComeBacksView &&
      other.loading == loading &&
      other.count == count &&
      other.next == next &&
      sameItems(other.sections, sections);

  @override
  int get hashCode =>
      Object.hash(loading, count, next, Object.hashAll(sections));

  @override
  String toString() => 'ComeBacksView($count, next: $next, $sections)';
}
