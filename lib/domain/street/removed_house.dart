import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';

/// A house whose number was removed from its street in edit mode: it sits
/// in the Corbeille (« 14ter Rue des Lilas · supprimé par Léa · 3 oct. »,
/// PLAN §5.11) with its status, « repasser » and building intact,
/// until someone restores it or it is purged.
///
/// It belongs to the `Street` aggregate: only the street root removes or
/// restores a house, and its number stays taken while it is removed.
final class RemovedHouse {
  const RemovedHouse({required this.house, required this.removal});

  /// The house exactly as it was when removed.
  final House house;

  /// Who removed it and when.
  final ChangeStamp removal;

  HouseNumber get number => house.number;

  /// This removed house, and its removal, stamped by [member] at the same
  /// times (see `Street.restampedBy`).
  RemovedHouse restampedBy(MemberId member) => RemovedHouse(
    house: house.restampedBy(member),
    removal: removal.restampedBy(member),
  );

  @override
  bool operator ==(Object other) =>
      other is RemovedHouse && other.house == house && other.removal == removal;

  @override
  int get hashCode => Object.hash(house, removal);

  @override
  String toString() => 'RemovedHouse($house, $removal)';
}
