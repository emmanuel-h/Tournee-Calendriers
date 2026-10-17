import 'package:tournee_calendriers/domain/shared/text_length.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

// The view state of the Fiche maison (PLAN §5.7, mockup House): what the
// sheet of one house shows, as plain data tested without widgets. The sheet
// of a door of a building, and the building's own « Repasser », show the
// same controls and share this state.

/// The length limit of the hint field of the sheet, counted exactly as the
/// domain counts it: Unicode code points of the trimmed text
/// ([characterCount]).
///
/// Flutter's `TextField.maxLength` counts what the eye sees as one symbol
/// (a family emoji is 1 there, 5 code points here), so the field could hold
/// a text the domain refuses. The sheet asks this instead, and refuses the
/// edit with a message rather than letting such a text in.
final class TextLimit {
  const TextLimit._(this.max);

  /// The hint of a « repasser »: [ComeBack.maxHintLength] characters.
  static const comeBackHint = TextLimit._(ComeBack.maxHintLength);

  /// The most characters the text may hold.
  final int max;

  /// The characters of [text] that count: the spaces and line breaks
  /// around it are dropped when it is stored, so they do not count.
  int count(String text) => characterCount(text.trim());

  /// Whether the domain takes [text] (`ComeBack.create`).
  bool accepts(String text) => count(text) <= max;
}

/// Who made the last change, as the sheet names them (PLAN §5.7).
///
/// `sealed`: the sheet words each case its own way.
sealed class ChangeAuthor {
  const ChangeAuthor();
}

/// The member using the phone: « Modifié par vous ».
final class ChangedByMe extends ChangeAuthor {
  const ChangedByMe();

  @override
  bool operator ==(Object other) => other is ChangedByMe;

  @override
  int get hashCode => (ChangedByMe).hashCode;

  @override
  String toString() => 'ChangedByMe';
}

/// A member of the open tournée, by their first name: « Modifié par Léa ».
final class ChangedByMember extends ChangeAuthor {
  const ChangedByMember(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      other is ChangedByMember && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'ChangedByMember($name)';
}

/// When the house was last changed, and by whom when it is known, for the
/// line « Modifié par Léa · 14:02 » or « Modifié le 3 oct. à 14:02 ».
///
/// `sealed`: the sheet words each case its own way.
sealed class LastChange {
  const LastChange(this.at, {this.by});

  /// The change made at [at] (UTC, as stored) by [by], seen at [now] (UTC,
  /// from the `Clock`): today or earlier, judged on the phone's calendar
  /// day.
  factory LastChange.of(
    DateTime at, {
    required DateTime now,
    ChangeAuthor? by,
  }) {
    final local = at.toLocal();
    final today = now.toLocal();
    final sameDay =
        local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
    return sameDay
        ? ChangedToday(local, by: by)
        : ChangedEarlier(local, by: by);
  }

  /// The time of the change, in the phone's time zone.
  final DateTime at;

  /// Who made it; null when the phone cannot name them (no tournée open,
  /// or a member no longer in its team).
  final ChangeAuthor? by;
}

/// Changed today: only the time is shown.
final class ChangedToday extends LastChange {
  const ChangedToday(super.at, {super.by});

  @override
  bool operator ==(Object other) =>
      other is ChangedToday && other.at == at && other.by == by;

  @override
  int get hashCode => Object.hash(ChangedToday, at, by);

  @override
  String toString() => 'ChangedToday($at, $by)';
}

/// Changed before today: the day and the time are shown.
final class ChangedEarlier extends LastChange {
  const ChangedEarlier(super.at, {super.by});

  @override
  bool operator ==(Object other) =>
      other is ChangedEarlier && other.at == at && other.by == by;

  @override
  int get hashCode => Object.hash(ChangedEarlier, at, by);

  @override
  String toString() => 'ChangedEarlier($at, $by)';
}

/// What a sheet of marks is about. `sealed`: the sheet titles each case
/// its own way and shows the controls that case has.
sealed class SheetSubject {
  const SheetSubject();
}

/// A single house: its status, and « Transformer en immeuble… ».
final class HouseSubject extends SheetSubject {
  const HouseSubject();
}

/// A building's own « repasser » (« Repasser » under the grid). No status: a building's status comes from its doors.
final class BuildingSubject extends SheetSubject {
  const BuildingSubject();
}

/// One door of a building (held in the grid). Its floor and label are in
/// the key the sheet was opened with.
final class DoorSubject extends SheetSubject {
  const DoorSubject({required this.staircase});

  /// Null when the building has a single staircase: it is not named then,
  /// as the grid shows no staircase control.
  final StaircaseName? staircase;

  @override
  bool operator ==(Object other) =>
      other is DoorSubject && other.staircase == staircase;

  @override
  int get hashCode => staircase.hashCode;

  @override
  String toString() => 'DoorSubject($staircase)';
}

/// Everything the Fiche maison shows. `sealed`: the sheet handles each case.
sealed class HouseSheetState {
  const HouseSheetState();
}

/// The street is being read from the phone (a moment, at most).
final class HouseSheetLoading extends HouseSheetState {
  const HouseSheetLoading();
}

/// What the sheet shows is no longer on the phone: the number was removed,
/// a house became a building (or the reverse), a door went with a new
/// layout, or the street went to the Corbeille.
final class HouseSheetGone extends HouseSheetState {
  const HouseSheetGone();
}

/// The house (or building, or door), ready to change.
final class HouseSheetShown extends HouseSheetState {
  const HouseSheetShown({
    required this.streetName,
    required this.number,
    required this.status,
    required this.comeBack,
    required this.comeBackHint,
    required this.lastChange,
    this.subject = const HouseSubject(),
    this.tries = 0,
  });

  final String streetName;
  final HouseNumber number;

  /// Null for a [BuildingSubject]: the sheet then has no status control.
  final VisitStatus? status;

  /// « Repasser » is the status of the house or door, or is ticked for a
  /// building itself. The hint field takes text only then: on a house or
  /// door it is always shown, greyed otherwise, so choosing a status never
  /// moves the sheet.
  final bool comeBack;

  /// The hint of the « repasser »; empty when there is none.
  final String comeBackHint;

  /// Null when nobody has changed it yet.
  final LastChange? lastChange;

  final SheetSubject subject;

  /// How many times nobody was home (#80): « 2 passages sans personne ».
  final int tries;

  /// « Repassé, toujours personne » shows, with the count of tries, while
  /// the house or door is « personne » or « repasser »: the ones the team
  /// comes back to. Never on a building itself, which has no status.
  bool get offersNobodyHomeAgain =>
      status == VisitStatus.nobodyHome || status == VisitStatus.comeBack;
}
