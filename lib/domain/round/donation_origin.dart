import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// The house or door a don of the tournée on was noted from (PLAN §5.21):
/// the house [number] of the [street], or its [door] when it is a
/// building.
///
/// Known **on the phone only, and only until the tournée is validated**:
/// `Round.validate` leaves it behind, so nothing that leaves the phone ties
/// money to an address (PLAN §8.3). It lets a ✓ taken back take its own
/// dons out of the tournée.
final class DonationOrigin {
  const DonationOrigin({required this.street, required this.number, this.door});

  final StreetId street;
  final HouseNumber number;

  /// The door of the building [number]; null for a single house.
  final DwellingKey? door;

  /// The house or door [change] takes away from ✓ (« Fait »), whatever it
  /// becomes (✗, ↻, ○, or ⊘: a refusal took no calendar either); null for
  /// a change that leaves ✓ where it was.
  ///
  /// Only the marks of the status picker, « De nouveau personne » and the
  /// undo of either move a status, as for `RoundVisit.of`. A house removed
  /// in edit mode, or its street deleted, keeps its dons (PLAN §5.21). The
  /// `switch` names every change, so a new one must be placed here.
  static DonationOrigin? leftDoneBy(StreetChange change) => switch (change) {
    HouseMarked(:final streetId, :final before, :final status) => _ifLeft(
      before.status,
      status,
      streetId,
      before.number,
    ),
    HouseNobodyHomeAgain(:final streetId, :final before) => _ifLeft(
      before.status,
      VisitStatus.nobodyHome,
      streetId,
      before.number,
    ),
    HouseReverted(:final streetId, :final replaced, :final house) => _ifLeft(
      replaced.status,
      house.status,
      streetId,
      replaced.number,
    ),
    DwellingMarked(
      :final streetId,
      :final number,
      :final key,
      :final before,
      :final status,
    ) =>
      _ifLeft(before.status, status, streetId, number, key),
    DwellingNobodyHomeAgain(
      :final streetId,
      :final number,
      :final key,
      :final before,
    ) =>
      _ifLeft(before.status, VisitStatus.nobodyHome, streetId, number, key),
    DwellingReverted(
      :final streetId,
      :final number,
      :final key,
      :final replaced,
      :final dwelling,
    ) =>
      _ifLeft(replaced.status, dwelling.status, streetId, number, key),
    ComeBackSet() ||
    DwellingComeBackSet() ||
    // A calendar more or less: the house is ✓ before and after.
    HouseCalendarsCounted() ||
    DwellingCalendarsCounted() ||
    BuildingLaidOut() ||
    BuildingRemoved() ||
    NumberRenamed() ||
    StreetDeleted() ||
    StreetRestored() ||
    StreetShapeFilled() ||
    StreetPartChanged() ||
    NumbersAdded() ||
    NumberRemoved() ||
    NumberRestored() ||
    NumbersPurged() ||
    StreetRenamed() => null,
  };

  static DonationOrigin? _ifLeft(
    VisitStatus before,
    VisitStatus after,
    StreetId street,
    HouseNumber number, [
    DwellingKey? door,
  ]) => before == VisitStatus.done && after != VisitStatus.done
      ? DonationOrigin(street: street, number: number, door: door)
      : null;

  @override
  bool operator ==(Object other) =>
      other is DonationOrigin &&
      other.street == street &&
      other.number == number &&
      other.door == door;

  @override
  int get hashCode => Object.hash(street, number, door);

  @override
  String toString() => [
    'DonationOrigin(${street.value}, ${number.label}',
    if (door case final door?) ', ${door.id}',
    ')',
  ].join();
}
