import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// Why [AddStreetFromMap] added nothing. Each case is phrased in French by
/// the card.
enum AddStreetFailure {
  /// The tournée has the street already, out of the Corbeille (a teammate
  /// added it meanwhile, or a second tap): the card shows it instead.
  alreadyInSector,

  /// The numbers the BAN gave break a rule of the street (a number twice):
  /// a service answering nonsense.
  serviceError,
}

/// « Ajouter au secteur » on the street card (PLAN §5.4): stores the street the card shows, with the
/// numbers and positions `LookUpStreet` read from the BAN, and its shape
/// on the map.
///
/// - **The shape** is the road the card found already, when it did
///   (`LookUpStreetShape`): adding never waits for the map. Without it,
///   the street is added without shape, shows as its house dots, and gets
///   its line later (`FillStreetShape`, PLAN §5.3).
/// - **The part** chosen on « Partie de la rue » (PLAN §5.15) is stored
///   with the street, and only the numbers it holds: the others are never
///   stored.
/// - **A street of the Corbeille** comes back with its marks, as importing
///   it again would (PLAN §6.1), and with its own part: its row offers
///   none to choose, it is changed afterwards in edit mode.
final class AddStreetFromMap {
  const AddStreetFromMap(this._streets, this._ids);

  final StreetRepository _streets;
  final IdGenerator _ids;

  /// Adds the street of [numbers] to the tournée and returns it as stored.
  ///
  /// [shape] is the road the card found already (`LookUpStreetShape`,
  /// simplified), stored as it is; none while the card has not found it.
  /// [part] is the part of the street the secteur holds, the whole street
  /// by default.
  Future<Result<Street, AddStreetFailure>> call(
    StreetNumbers numbers, {
    StreetShape shape = StreetShape.none,
    StreetPart part = StreetPart.whole,
  }) async {
    final known = await _streets.findByBanId(numbers.id);
    if (known != null) {
      if (!known.isDeleted) return const Err(AddStreetFailure.alreadyInSector);
      return Ok(await _bringBack(known));
    }

    switch (Street.create(
      id: StreetId(_ids.newId()),
      name: numbers.name.text,
      commune: numbers.commune,
      banId: numbers.id,
      shape: shape,
      part: part,
      houses: [
        for (final number in numbers.heldBy(part))
          House(number: number.number, position: number.position),
      ],
    )) {
      case Err():
        return const Err(AddStreetFailure.serviceError);
      case Ok(value: final street):
        await _streets.add(street);
        return Ok(street);
    }
  }

  /// [deleted] out of the Corbeille, with its marks.
  Future<Street> _bringBack(Street deleted) async {
    final (restored, change) = deleted.restore();
    await _streets.save(restored, change);
    return restored;
  }
}
