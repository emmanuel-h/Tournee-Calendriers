import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// Why a list of houses cannot make a [Street].
enum NewStreetFailure {
  /// Two houses have the same number (`12bis` and `12 BIS` included).
  duplicateHouseNumber,
}

/// Why a command on one house of a [Street] was refused.
enum HouseChangeFailure {
  /// The street has no house with that number.
  unknownHouse,

  /// A « repasser » was asked on a house that is already done.
  comeBackOnDoneHouse,
}

/// A street of the tournée and its houses: the aggregate root that guards
/// every change to them (PLAN §6.1).
///
/// Invariants, true of every `Street`:
/// - each house number appears once;
/// - [houses] is sorted by [HouseNumber] (`3 < 3bis < 3A < 4`);
/// - a done house has no « repasser » (see [House]).
///
/// A `Street` is immutable. Each command returns a new street together with
/// the [StreetChange] it made, as a Dart record `(Street, Change)`; storage
/// writes only that change (PLAN §6.2). A command that can be refused
/// returns a [Result] instead of throwing.
final class Street {
  const Street._({
    required this.id,
    required this.name,
    required this.commune,
    required this.banId,
    required this.houses,
    required this.deletion,
  });

  /// Builds a street from its identity and its [houses], given in any order.
  ///
  /// Fails with [NewStreetFailure.duplicateHouseNumber] when two houses share
  /// a number. A street created with a [deletion] is in the Corbeille.
  static Result<Street, NewStreetFailure> create({
    required StreetId id,
    required String name,
    required Commune commune,
    BanStreetId? banId,
    Iterable<House> houses = const [],
    ChangeStamp? deletion,
  }) {
    // `..sort(…)` is a cascade: it sorts the new list and the expression
    // still evaluates to the list, not to the `void` that `sort` returns.
    final sorted = houses.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    // Once sorted, equal numbers sit next to each other.
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].number == sorted[i - 1].number) {
        return const Err(NewStreetFailure.duplicateHouseNumber);
      }
    }
    return Ok(
      Street._(
        id: id,
        name: name,
        commune: commune,
        banId: banId,
        houses: List.unmodifiable(sorted),
        deletion: deletion,
      ),
    );
  }

  final StreetId id;

  /// The name as the BAN writes it (« Rue des Lilas »).
  final String name;

  final Commune commune;

  /// The street in the BAN; null for a street typed in by hand.
  final BanStreetId? banId;

  /// Every house, sorted by number. The list cannot be modified (it throws
  /// an `UnsupportedError`): houses change only through the commands below.
  final List<House> houses;

  /// Who sent the street to the Corbeille and when; null when it is not
  /// deleted.
  final ChangeStamp? deletion;

  /// Whether the street is in the Corbeille.
  bool get isDeleted => deletion != null;

  /// The odd side of the street (left column of PLAN §5.6), in order.
  List<House> get oddHouses =>
      List.unmodifiable(houses.where((house) => house.number.isOdd));

  /// The even side of the street (right column), 0 included, in order.
  List<House> get evenHouses =>
      List.unmodifiable(houses.where((house) => house.number.isEven));

  /// The progress of the whole street: the sum of its houses' progress.
  Progress get progress =>
      houses.fold(Progress.empty, (sum, house) => sum + house.progress);

  /// Gives the house at [number] the [status], as [by] at [at].
  ///
  /// Marking a house done also removes its « repasser »: the residents have
  /// been seen, there is nothing left to come back for (the tap logic of the
  /// approved Main mockup). Any other status keeps it.
  Result<(Street, HouseMarked), HouseChangeFailure> markHouse(
    HouseNumber number,
    VisitStatus status, {
    required MemberId by,
    required DateTime at,
  }) {
    final index = _indexOf(number);
    if (index < 0) return const Err(HouseChangeFailure.unknownHouse);
    final before = houses[index];
    final stamp = ChangeStamp(by: by, at: at);
    // The House factory drops the come-back when the status is done.
    final after = House(
      number: number,
      status: status,
      comeBack: before.comeBack,
      note: before.note,
      lastChange: stamp,
    );
    return Ok((
      _withHouseAt(index, after),
      HouseMarked(streetId: id, before: before, stamp: stamp, status: status),
    ));
  }

  /// Sets the « repasser » of the house at [number] to [comeBack], or
  /// removes it when [comeBack] is null, as [by] at [at].
  ///
  /// Refused with [HouseChangeFailure.comeBackOnDoneHouse] on a done house:
  /// it would be dropped at once (see [House]), and silently ignoring the
  /// request would hide that from the user. Move the house out of done first.
  Result<(Street, ComeBackSet), HouseChangeFailure> setComeBack(
    HouseNumber number,
    ComeBack? comeBack, {
    required MemberId by,
    required DateTime at,
  }) {
    final index = _indexOf(number);
    if (index < 0) return const Err(HouseChangeFailure.unknownHouse);
    final before = houses[index];
    if (comeBack != null && before.status == VisitStatus.done) {
      return const Err(HouseChangeFailure.comeBackOnDoneHouse);
    }
    final stamp = ChangeStamp(by: by, at: at);
    final after = House(
      number: number,
      status: before.status,
      comeBack: comeBack,
      note: before.note,
      lastChange: stamp,
    );
    return Ok((
      _withHouseAt(index, after),
      ComeBackSet(
        streetId: id,
        before: before,
        stamp: stamp,
        comeBack: comeBack,
      ),
    ));
  }

  /// Replaces the note of the house at [number] with [note] (erase it with
  /// [Note.empty]), as [by] at [at].
  Result<(Street, NoteSet), HouseChangeFailure> setNote(
    HouseNumber number,
    Note note, {
    required MemberId by,
    required DateTime at,
  }) {
    final index = _indexOf(number);
    if (index < 0) return const Err(HouseChangeFailure.unknownHouse);
    final before = houses[index];
    final stamp = ChangeStamp(by: by, at: at);
    final after = House(
      number: number,
      status: before.status,
      comeBack: before.comeBack,
      note: note,
      lastChange: stamp,
    );
    return Ok((
      _withHouseAt(index, after),
      NoteSet(streetId: id, before: before, stamp: stamp, note: note),
    ));
  }

  /// Sends the street to the Corbeille, as [by] at [at]: it is hidden but
  /// keeps its houses, statuses and notes (PLAN §5.11). Deleting a street
  /// already in the Corbeille records the latest deletion.
  (Street, StreetDeleted) delete({required MemberId by, required DateTime at}) {
    final deletion = ChangeStamp(by: by, at: at);
    return (
      _copy(houses: houses, deletion: deletion),
      StreetDeleted(streetId: id, deletion: deletion),
    );
  }

  /// Brings the street back from the Corbeille, houses untouched.
  (Street, StreetRestored) restore() =>
      (_copy(houses: houses, deletion: null), StreetRestored(streetId: id));

  /// The position of [number] in [houses], or -1 when the street has none.
  int _indexOf(HouseNumber number) =>
      houses.indexWhere((house) => house.number == number);

  /// This street with [house] in place of the house at [index]. The number
  /// does not change, so the order still holds.
  Street _withHouseAt(int index, House house) {
    final changed = houses.toList()..[index] = house;
    return _copy(houses: List.unmodifiable(changed), deletion: deletion);
  }

  /// This street, same identity, with [houses] and [deletion]. Both are
  /// required so no call can forget one (null is a real value of
  /// [deletion]: not in the Corbeille).
  Street _copy({required List<House> houses, required ChangeStamp? deletion}) =>
      Street._(
        id: id,
        name: name,
        commune: commune,
        banId: banId,
        houses: houses,
        deletion: deletion,
      );
}
