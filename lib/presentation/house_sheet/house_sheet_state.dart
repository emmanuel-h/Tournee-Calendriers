import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/presentation/round/given_donation.dart';

// The view state of the status picker (PLAN §5.6, mockups House,
// HouseNobody, HouseComeBack): what the picker of one house or one door
// shows, as plain data tested without widgets. The building's own
// « Repasser » sheet (under its grid) shares it.

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

/// A member of the open secteur, by their first name: « Modifié par Léa ».
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

  /// Who made it; null when the phone cannot name them (the team not read
  /// yet, or a member no longer in it).
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

/// A single house: its status picker.
final class HouseSubject extends SheetSubject {
  const HouseSubject();
}

/// A building's own « repasser » (« Repasser » under the grid). No status: a building's status comes from its doors.
final class BuildingSubject extends SheetSubject {
  const BuildingSubject();
}

/// One door of a building (tapped in the grid). Its floor and label are in
/// the key the picker was opened with.
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

/// Everything the status picker shows. `sealed`: the sheet handles each
/// case.
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
    required this.comeBackTime,
    required this.lastChange,
    this.subject = const HouseSubject(),
    this.tries = 0,
    this.calendars = 0,
    this.roundOn = false,
  });

  final String streetName;
  final HouseNumber number;

  /// Null for a [BuildingSubject]: the sheet then has no status control.
  final VisitStatus? status;

  /// « Repasser » is the status of the house or door, or is ticked for a
  /// building itself. « Quand repasser ? » takes a day and an hour only
  /// then; greyed otherwise (a teammate changed the status meanwhile).
  final bool comeBack;

  /// « Quand repasser ? »: the days offered, the day and hour chosen.
  final ComeBackTime comeBackTime;

  /// Null when nobody has changed it yet.
  final LastChange? lastChange;

  final SheetSubject subject;

  /// How many times nobody was home (#80): « 2 passages sans personne ».
  final int tries;

  /// How many calendars the house or door took (#114): one or more while
  /// it is done, 0 otherwise.
  final int calendars;

  /// A tournée is on in the secteur shown (PLAN §5.13): « Fait » asks for
  /// the don, and a house done offers « + Ajouter un don ».
  final bool roundOn;

  /// « + Ajouter un don » shows under the statuses: the house or door is
  /// done and a tournée is on, so it may take another don (PLAN §5.6).
  bool get offersDonation => roundOn && status == VisitStatus.done;

  /// « ✗ Personne » reads « ✗ De nouveau personne » and counts one more try
  /// (PLAN §5.6) on a house or door the team comes back to: « personne » or
  /// « repasser », already tried with nobody home. Never on a building
  /// itself, which has no status.
  bool get offersNobodyHomeAgain =>
      tries > 0 &&
      (status == VisitStatus.nobodyHome || status == VisitStatus.comeBack);

  /// « ✗ 2 passages sans personne » shows under the statuses once a try is
  /// counted. « À faire » has none: it starts the count again (§6.1).
  bool get showsTries => tries > 0;

  /// « 1 calendrier » / « 2 calendriers » and its « − » show under the
  /// statuses on a house or door done, tournée or not, so a mistake is
  /// fixed afterwards too (PLAN §5.6).
  bool get showsCalendars => status == VisitStatus.done;

  /// « − » takes one calendar away; disabled at one: a ✓ took a calendar.
  bool get canRemoveCalendar => calendars > 1;
}

/// What one choice of the status picker stored (PLAN §5.6): the house or
/// door now has [status] and shows [tries] (null below two, see
/// `shownTries`), for the snackbar « N° 7 : personne (3e passage) » and
/// what screen readers hear. [change] is what its « Annuler » undoes: the
/// screen behind keeps it (`UndoesLastChange.keepForUndo`), as the picker
/// is gone by then.
///
/// [donation] is the don given after a « Fait » during a tournée
/// (« N° 7 fait · 10 € en espèces »), which « Annuler » takes back too;
/// null otherwise.
final class StoredStatus {
  const StoredStatus({
    required this.status,
    required this.tries,
    required this.change,
    this.donation,
  });

  final VisitStatus status;
  final int? tries;
  final StreetChange change;
  final GivenDonation? donation;

  /// The same, with the don given after it.
  StoredStatus withDonation(GivenDonation donation) => StoredStatus(
    status: status,
    tries: tries,
    change: change,
    donation: donation,
  );

  @override
  bool operator ==(Object other) =>
      other is StoredStatus &&
      other.status == status &&
      other.tries == tries &&
      other.change == change &&
      other.donation == donation;

  @override
  int get hashCode => Object.hash(status, tries, change, donation);

  @override
  String toString() => 'StoredStatus($status, $tries, $change, $donation)';
}
