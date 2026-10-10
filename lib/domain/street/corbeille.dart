import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';

/// Something deleted that the team can still bring back (« Corbeille »,
/// PLAN §5.11): a whole street, or one number of a street.
///
/// `sealed`: [DeletedStreet] and [RemovedNumber] are the only kinds, so a
/// `switch` over an item handles both.
sealed class CorbeilleItem {
  const CorbeilleItem({
    required this.streetId,
    required this.streetName,
    required this.removal,
  });

  /// The street deleted, or the street the number was removed from.
  final StreetId streetId;
  final StreetName streetName;

  /// Who deleted it and when (« supprimée par Paul · hier »).
  final ChangeStamp removal;
}

/// A street in the Corbeille (« Rue Gambetta · 22 numéros »).
final class DeletedStreet extends CorbeilleItem {
  const DeletedStreet({
    required super.streetId,
    required super.streetName,
    required super.removal,
    required this.numberCount,
  });

  /// The numbers the street shows once restored.
  final int numberCount;

  @override
  bool operator ==(Object other) =>
      other is DeletedStreet &&
      other.streetId == streetId &&
      other.streetName == streetName &&
      other.removal == removal &&
      other.numberCount == numberCount;

  @override
  int get hashCode => Object.hash(streetId, streetName, removal, numberCount);

  @override
  String toString() => 'DeletedStreet(${streetId.value}, $numberCount)';
}

/// A number removed from a street that is not itself in the Corbeille
/// (« 14ter Rue des Lilas »).
final class RemovedNumber extends CorbeilleItem {
  const RemovedNumber({
    required super.streetId,
    required super.streetName,
    required super.removal,
    required this.number,
  });

  final HouseNumber number;

  @override
  bool operator ==(Object other) =>
      other is RemovedNumber &&
      other.streetId == streetId &&
      other.streetName == streetName &&
      other.removal == removal &&
      other.number == number;

  @override
  int get hashCode => Object.hash(streetId, streetName, removal, number);

  @override
  String toString() => 'RemovedNumber(${streetId.value}, ${number.label})';
}

/// What the Corbeille holds among [streets] (every street of the tournée,
/// deleted or not): each deleted street, and each removed number of the
/// streets not deleted, the latest removal first.
///
/// The numbers removed from a deleted street are not listed: restoring the
/// street is what brings them in sight again, still in the Corbeille.
///
/// Removals made at the same instant are ordered by street name (the
/// French way, see `compareFrench`), then street id, then number, so the
/// list never depends on the order storage gave.
List<CorbeilleItem> corbeilleOf(Iterable<Street> streets) {
  final items = <CorbeilleItem>[
    for (final street in streets)
      if (street.deletion case final deletion?)
        DeletedStreet(
          streetId: street.id,
          streetName: street.name,
          removal: deletion,
          numberCount: street.houses.length,
        )
      else
        for (final removed in street.removedHouses)
          RemovedNumber(
            streetId: street.id,
            streetName: street.name,
            removal: removed.removal,
            number: removed.number,
          ),
  ];
  return List.unmodifiable(items..sort(_latestFirst));
}

int _latestFirst(CorbeilleItem a, CorbeilleItem b) {
  // b before a: the later time first.
  final byTime = b.removal.at.compareTo(a.removal.at);
  if (byTime != 0) return byTime;
  final byName = compareFrench(a.streetName.text, b.streetName.text);
  if (byName != 0) return byName;
  final byId = a.streetId.value.compareTo(b.streetId.value);
  if (byId != 0) return byId;
  // Same street: both are numbers, as a deleted street lists none.
  return (a as RemovedNumber).number.compareTo((b as RemovedNumber).number);
}
