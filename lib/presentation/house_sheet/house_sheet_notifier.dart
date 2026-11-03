import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/application/use_cases/set_house_details.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/shared/calendar_day.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/nobody_home_tries.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/round/given_donation.dart';
import 'package:tournee_calendriers/presentation/round/round_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';
import 'package:tournee_calendriers/presentation/street/follows_street.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart'
    show shownTries;

/// Which house a sheet shows. A record: two records with the same fields
/// are equal, so `houseSheetProvider(key)` finds the same notifier for the
/// same house.
typedef HouseSheetKey = ({StreetId street, HouseNumber number});

/// Which door of which building a door sheet shows.
typedef DoorSheetKey = ({
  StreetId street,
  HouseNumber number,
  DwellingKey door,
});

/// The state of the status picker of one single house (PLAN §5.6).
///
/// `family`: one notifier per house; `autoDispose`: it stops following the
/// street once the sheet is closed.
final houseSheetProvider = NotifierProvider.autoDispose
    .family<HouseSheetNotifier, HouseSheetState, HouseSheetKey>(
      HouseSheetNotifier.new,
    );

/// The state of the « Repasser » sheet of a building itself.
final buildingDetailsProvider = NotifierProvider.autoDispose
    .family<BuildingDetailsNotifier, HouseSheetState, HouseSheetKey>(
      BuildingDetailsNotifier.new,
    );

/// The state of the status picker of one door of a building (tap a door).
final doorSheetProvider = NotifierProvider.autoDispose
    .family<DoorSheetNotifier, HouseSheetState, DoorSheetKey>(
      DoorSheetNotifier.new,
    );

/// The marks a sheet shows and changes, read from the street.
typedef _Marks = ({
  SheetSubject subject,
  VisitStatus? status,
  ComeBack? comeBack,
  ChangeStamp? lastChange,
  NobodyHomeTries tries,
});

/// Follows one house, building or door of a street on the phone
/// (`ObserveStreet`, offline) and stores each choice of its sheet: the
/// status of the picker (« De nouveau personne » among them, PLAN §5.6)
/// and the day and hour of the « repasser »; on a building itself, its own
/// « Repasser » box instead of a status. The three sheets differ only in
/// what they read ([_marksIn]) and the use case that stores ([_storer]);
/// the rules below are written once.
///
/// - **Nothing changed, nothing stored.** A status, a day or an hour
///   already there stores nothing, so opening and closing a sheet stamps
///   nothing.
/// - **One change at a time.** Each change waits for the previous one to be
///   stored, then decides on the marks as they then are. Started together
///   (a day chosen, then « Fait » tapped at once), two changes would both
///   start from the same street, and the second would erase the first.
///
/// `abstract base`: a class to extend, not to use alone; `base` keeps its
/// subclasses `final`, so nobody outside this file can change the rules.
abstract base class MarksSheetNotifier extends Notifier<HouseSheetState>
    with FollowsStreet<HouseSheetState> {
  /// The last change asked; the next one starts when it ends.
  Future<void> _pending = Future.value();

  /// The open tournée as last read, for the name of who made the last
  /// change; null while none is open or it cannot be read.
  Sector? _team;

  /// A tournée (one outing, PLAN §5.13) is on in the secteur shown.
  var _roundOn = false;

  StreetId get _streetId;
  HouseNumber get _number;

  /// The marks the sheet shows in [street] (not deleted), or null when the
  /// house, building or door is not there.
  _Marks? _marksIn(Street street);

  /// The use case that stores a mark, read from `ref` now: a change queued
  /// as the sheet closes runs when this notifier may be disposed. It gives
  /// the change stored, or null when the street refused it.
  Future<StreetChange?> Function(Mark mark) _storer();

  @override
  HouseSheetState build() {
    followStreet(_streetId);
    _followTeam();
    _followRound();
    return render();
  }

  /// Follows whether a tournée is on (`roundProvider`), which makes « Fait »
  /// ask for the don and a house done offer « + Ajouter un don ».
  /// `ref.listen` rather than `ref.watch`: a don added changes the
  /// tournée, and the sheet must not build again for it (its queue of
  /// changes would be lost).
  void _followRound() {
    ref.listen(roundProvider, (_, view) {
      _roundOn = view is RoundOn;
      state = render();
    });
    _roundOn = ref.read(roundProvider) is RoundOn;
  }

  /// Follows the open tournée's team (`ObserveTeam`, from the phone's copy
  /// offline), which names who made the last change. Nothing to follow
  /// while no tournée is open: the phone's own streets name nobody but
  /// the member on the phone.
  void _followTeam() {
    // Riverpod keeps the notifier when it builds again (another tournée
    // opened): the old team must not name anyone.
    _team = null;
    final sector = ref.watch(currentSectorProvider);
    if (sector == null) return;
    final subscription = ref.watch(observeTeamProvider)(sector.id).listen(
      (team) {
        _team = team;
        state = render();
      },
      // The team cannot be read (the member left): the sheet still
      // shows the time, without a name.
      onError: (Object _) {},
    );
    ref.onDispose(subscription.cancel);
  }

  /// Who made the change stamped [stamp], as the sheet names them: the
  /// member on the phone, a member of the open tournée, or nobody known.
  ChangeAuthor? _authorOf(ChangeStamp stamp) {
    if (stamp.by == ref.read(readCurrentMemberProvider)()) {
      return const ChangedByMe();
    }
    return switch (_team?.memberOf(stamp.by)) {
      final member? => ChangedByMember(member.name.text),
      null => null,
    };
  }

  /// A status tapped in the picker: gives [status] and returns what was
  /// stored, for the snackbar and its « Annuler »; null when nothing was
  /// (the status it already has, a building's own sheet, a refusal).
  /// Leaving « Repasser » drops its time (PLAN §6.1).
  ///
  /// « Personne » on a house or door that offers « De nouveau personne »
  /// ([HouseSheetShown.offersNobodyHomeAgain]) counts one more try instead,
  /// even when it already is « personne ».
  Future<StoredStatus?> setStatus(VisitStatus status) async {
    NobodyHomeTries? triesAfter;
    final change = await _change((marks) {
      final current = marks.status;
      if (current == null) return null;
      if (status == VisitStatus.nobodyHome && _comesBackTo(marks)) {
        triesAfter = marks.tries.next;
        return const NobodyHomeAgainMark();
      }
      if (current == status) return null;
      triesAfter = NobodyHomeTries.keptBy(status, marks.tries);
      return StatusMark(status);
    });
    return switch ((change, triesAfter)) {
      (final change?, final tries?) => StoredStatus(
        status: status,
        tries: shownTries(tries),
        change: change,
      ),
      _ => null,
    };
  }

  /// Whether [marks] are of a house or door the team comes back to after
  /// nobody was home: the rule of [HouseSheetShown.offersNobodyHomeAgain].
  static bool _comesBackTo(_Marks marks) =>
      marks.tries.count > 0 &&
      (marks.status == VisitStatus.nobodyHome ||
          marks.status == VisitStatus.comeBack);

  /// The « Repasser » box of a building's own sheet, ticked ([on]) or not.
  /// Ticking gives a « repasser » without time, which « Quand repasser ? »
  /// then completes; unticking drops the time too. Nothing happens on a house or
  /// a door, whose « repasser » is a status ([setStatus]).
  Future<void> setComeBack({required bool on}) => _change(
    (marks) => marks.status != null || (marks.comeBack != null) == on
        ? null
        : ComeBackMark(on ? ComeBack.withoutTime : null),
  );

  /// A day chip of « Quand repasser ? »: comes back on [day], at the hour
  /// already chosen; null (the chosen chip tapped again) leaves no time at
  /// all, the hour with it. Nothing happens without a « repasser » (the
  /// block is greyed then).
  Future<void> chooseComeBackDay(CalendarDay? day) => _change(
    (marks) => _comeBackMark(
      marks,
      (stored) =>
          ComeBack.create(day: day, hour: day == null ? null : stored.hour),
    ),
  );

  /// The hour list of « Quand repasser ? »: [hour], or « Pas d'heure »
  /// (null). Nothing happens without a « repasser », nor before a day is
  /// chosen (the list is greyed then: an hour needs a day).
  Future<void> chooseComeBackHour(int? hour) => _change(
    (marks) => _comeBackMark(
      marks,
      (stored) => ComeBack.create(day: stored.day, hour: hour),
    ),
  );

  /// The mark giving the « repasser » of [marks] the time [timeFrom] makes
  /// of it; null when there is no « repasser », when the time is refused,
  /// or when it is the one already stored.
  static Mark? _comeBackMark(
    _Marks marks,
    Result<ComeBack, ComeBackFailure> Function(ComeBack stored) timeFrom,
  ) {
    final stored = marks.comeBack;
    if (stored == null) return null;
    return switch (timeFrom(stored)) {
      Ok(:final value) when value != stored => ComeBackMark(value),
      Ok() || Err() => null,
    };
  }

  /// A don given in « Montant du don » (PLAN §5.6): it joins the tournée on
  /// (`AddDonation`), never the house. Returns where it went, for the
  /// snackbar and its « Annuler »; null when no tournée is on any more
  /// (validated meanwhile on another screen).
  Future<GivenDonation?> giveDonation(Donation donation) async =>
      switch (await ref.read(addDonationProvider)(donation)) {
        // The tournée adds a don last.
        Ok(value: final round) => GivenDonation(
          index: round.donations.length - 1,
          donation: donation,
        ),
        Err() => null,
      };

  /// ✕ of « Montant du don » after a « Fait » (PLAN §5.6): no calendar was
  /// handed over after all, so the house or door goes back as it was
  /// before [change] (status, time, tries), and the tournée counts it no
  /// more (`UndoLastChange`). Queued after the changes asked before.
  Future<void> takeBack(StreetChange change) {
    // Read now: the sheet is closing, this notifier may be disposed by the
    // time the queue reaches it.
    final undo = ref.read(undoLastChangeProvider);
    final step = _pending.then((_) => undo(change));
    _pending = step.then<void>((_) {}, onError: (Object _) {});
    return step;
  }

  /// Ends once every change asked so far is stored (or failed): « Annuler »
  /// of a sheet opened by a tap waits for it, so the undo of the tap comes
  /// after a day chosen just before, not under it.
  Future<void> get settled => _pending;

  /// Queues the change [markFor] makes on the marks as they are when its
  /// turn comes (null: nothing to change), and gives what was stored. A
  /// refused change leaves them as they are; the sheet shows it.
  Future<StreetChange?> _change(Mark? Function(_Marks marks) markFor) {
    final store = _storer();
    final step = _pending.then((_) async {
      final marks = _marks;
      if (marks == null) return null;
      final mark = markFor(marks);
      if (mark == null) return null;
      return store(mark);
    });
    // A change that failed to be stored (a full disk) must not block the
    // ones after it; its caller still gets the error through `step`.
    _pending = step.then<void>((_) {}, onError: (Object _) {});
    return step;
  }

  _Marks? get _marks => switch (street) {
    final street? => _marksIn(street),
    null => null,
  };

  @override
  HouseSheetState render() {
    if (!streetRead) return const HouseSheetLoading();
    final marks = _marks;
    if (marks == null) return const HouseSheetGone();
    final stamp = marks.lastChange;
    // The clock tells « today » from « earlier »; reading it here, and not
    // `DateTime.now()`, lets the tests fix the day.
    final now = ref.read(clockProvider).now();
    return HouseSheetShown(
      streetName: street!.name.text,
      number: _number,
      subject: marks.subject,
      status: marks.status,
      comeBack: marks.comeBack != null,
      // The days offered start today on the phone's calendar.
      comeBackTime: ComeBackTime.of(
        marks.comeBack,
        today: CalendarDay.of(now.toLocal()),
      ),
      tries: marks.tries.count,
      roundOn: _roundOn,
      lastChange: stamp == null
          ? null
          : LastChange.of(stamp.at, now: now, by: _authorOf(stamp)),
    );
  }
}

/// The status picker of a single house, stored through `SetHouseDetails`.
/// A house that became a building is gone for this sheet.
final class HouseSheetNotifier extends MarksSheetNotifier {
  HouseSheetNotifier(this.key);

  final HouseSheetKey key;

  @override
  StreetId get _streetId => key.street;

  @override
  HouseNumber get _number => key.number;

  @override
  _Marks? _marksIn(Street street) => switch (street.houseAt(key.number)) {
    final house? when !house.isBuilding => (
      subject: const HouseSubject(),
      status: house.status,
      comeBack: house.comeBack,
      lastChange: house.lastChange,
      tries: house.tries,
    ),
    _ => null,
  };

  @override
  Future<StreetChange?> Function(Mark mark) _storer() =>
      _storedBy(ref.read(setHouseDetailsProvider), key);
}

/// The building's own « repasser » (« Repasser » under the grid), stored
/// through `SetHouseDetails`, which sets a building's own. No status: its
/// doors carry them.
final class BuildingDetailsNotifier extends MarksSheetNotifier {
  BuildingDetailsNotifier(this.key);

  final HouseSheetKey key;

  @override
  StreetId get _streetId => key.street;

  @override
  HouseNumber get _number => key.number;

  @override
  _Marks? _marksIn(Street street) => switch (street.houseAt(key.number)) {
    final house? when house.isBuilding => (
      subject: const BuildingSubject(),
      status: null,
      comeBack: house.comeBack,
      lastChange: house.lastChange,
      tries: NobodyHomeTries.none,
    ),
    _ => null,
  };

  @override
  Future<StreetChange?> Function(Mark mark) _storer() =>
      _storedBy(ref.read(setHouseDetailsProvider), key);
}

/// Stores a mark of the house [key] through [setHouseDetails]: the change,
/// or null when the street refused it.
Future<StreetChange?> Function(Mark mark) _storedBy(
  SetHouseDetails setHouseDetails,
  HouseSheetKey key,
) =>
    (mark) async =>
        switch (await setHouseDetails(key.street, key.number, mark)) {
          Ok(:final value) => value,
          Err() => null,
        };

/// The picker of one door, stored through `MarkDwelling`: only that door is
/// stamped. A door dropped by a new layout is gone for this sheet.
final class DoorSheetNotifier extends MarksSheetNotifier {
  DoorSheetNotifier(this.key);

  final DoorSheetKey key;

  @override
  StreetId get _streetId => key.street;

  @override
  HouseNumber get _number => key.number;

  @override
  _Marks? _marksIn(Street street) {
    final building = street.houseAt(key.number)?.building;
    final door = building?.dwellingAt(key.door);
    if (building == null || door == null) return null;
    return (
      subject: DoorSubject(
        staircase: building.staircases.length > 1 ? key.door.staircase : null,
      ),
      status: door.status,
      comeBack: door.comeBack,
      lastChange: door.lastChange,
      tries: door.tries,
    );
  }

  @override
  Future<StreetChange?> Function(Mark mark) _storer() {
    final markDwelling = ref.read(markDwellingProvider);
    return (mark) async =>
        switch (await markDwelling(key.street, key.number, key.door, mark)) {
          Ok(:final value) => value,
          Err() => null,
        };
  }
}
