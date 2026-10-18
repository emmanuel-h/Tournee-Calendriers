import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// Why [AddStreetFromMap] added nothing. Each case is phrased in French by
/// the card.
enum AddStreetFailure {
  /// The tournée has the street already, out of the Corbeille (a teammate
  /// added it meanwhile, or a second tap): the card shows it instead.
  alreadyInTournee,

  /// The numbers the BAN gave break a rule of the street (a number twice):
  /// a service answering nonsense.
  serviceError,
}

/// « Ajouter et me l'attribuer » / « Ajouter sans m'attribuer » on the
/// street card (PLAN §5.4): stores the street the card shows, with the
/// numbers and positions `LookUpStreet` read from the BAN, and its shape
/// on the map.
///
/// - **The shape** is the road the card found already, when it did
///   (`LookUpStreetShape`): adding never waits for the map. Without it,
///   the street is added without shape, shows as its house dots, and gets
///   its line later (`FillStreetShape`, PLAN §5.3).
/// - **A street of the Corbeille** comes back with its marks, as importing
///   it again would (PLAN §6.1).
/// - **[assignToMe]** gives the street to the member on the phone: it joins
///   their « Mes rues ».
final class AddStreetFromMap {
  const AddStreetFromMap(this._streets, this._ids, this._identity);

  final StreetRepository _streets;
  final IdGenerator _ids;
  final IdentityProvider _identity;

  /// Adds the street of [numbers] to the tournée and returns it as stored.
  ///
  /// [shape] is the road the card found already (`LookUpStreetShape`,
  /// simplified), stored as it is; none while the card has not found it.
  Future<Result<Street, AddStreetFailure>> call(
    StreetNumbers numbers, {
    required bool assignToMe,
    StreetShape shape = StreetShape.none,
  }) async {
    final known = await _streets.findByBanId(numbers.id);
    if (known != null) {
      if (!known.isDeleted) return const Err(AddStreetFailure.alreadyInTournee);
      return Ok(await _bringBack(known, assignToMe: assignToMe));
    }

    switch (Street.create(
      id: StreetId(_ids.newId()),
      name: numbers.name.text,
      commune: numbers.commune,
      banId: numbers.id,
      shape: shape,
      assignees: {if (assignToMe) _identity.currentMember},
      houses: [
        for (final number in numbers.numbers)
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

  /// [deleted] out of the Corbeille, given to the member when [assignToMe]
  /// and they do not cover it yet.
  Future<Street> _bringBack(Street deleted, {required bool assignToMe}) async {
    final (restored, change) = deleted.restore();
    await _streets.save(restored, change);
    if (!assignToMe) return restored;
    switch (restored.take(_identity.currentMember)) {
      case Err():
        // They cover it already: nothing to change.
        return restored;
      case Ok(value: (final taken, final took)):
        await _streets.save(taken, took);
        return taken;
    }
  }
}
