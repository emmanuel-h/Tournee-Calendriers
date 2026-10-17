import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// Where the street to show on the card of « Ajouter des rues » comes from
/// (PLAN §5.4). `sealed`: [LookUpStreet] handles each one.
sealed class StreetLookup {
  const StreetLookup();
}

/// A tap on a road of the map, at [point].
final class StreetAtPoint extends StreetLookup {
  const StreetAtPoint(this.point);

  final GeoPoint point;
}

/// A street chosen among the results of the search box (`SearchStreet`).
final class FoundStreet extends StreetLookup {
  const FoundStreet(this.match);

  final StreetMatch match;
}

/// The street the card is about. `sealed`: the card adapts to each case.
sealed class LookedUpStreet {
  const LookedUpStreet(this.match);

  /// The BAN street: its name and commune for the card, its point to
  /// centre the map on.
  final StreetMatch match;
}

/// The tournée does not have the street (or only in its Corbeille): the
/// card offers « Ajouter et me l'attribuer » and « Ajouter sans
/// m'attribuer », which give [numbers] to `AddStreetFromMap`.
final class StreetToAdd extends LookedUpStreet {
  const StreetToAdd(super.match, this.numbers);

  /// The numbers of the street, each with its position when the BAN has
  /// one.
  final StreetNumbers numbers;

  /// « 19 numéros » on the card.
  int get numberCount => numbers.numbers.length;
}

/// The tournée has the street already, out of the Corbeille: the card shows
/// its progress and who covers it, and offers to take it
/// (`TakeStreet`) or open it.
final class StreetOfTheTournee extends LookedUpStreet {
  const StreetOfTheTournee(super.match, this.street);

  final Street street;
}

/// Finds the BAN street of a tap on the map or of a search result, and
/// whether the tournée has it, for the street card (PLAN §5.4). Changes
/// nothing.
///
/// Needs the network: the geocoder for a tap, the BAN for the numbers of a
/// street the tournée does not have. A street of the tournée needs no
/// numbers: they are in the street already.
final class LookUpStreet {
  const LookUpStreet(this._directory, this._streets);

  final AddressDirectory _directory;
  final StreetRepository _streets;

  /// The street of [lookup], or why the BAN could not tell:
  /// [AddressDirectoryFailure.notFound] when no street is near a tap,
  /// [AddressDirectoryFailure.noNetwork] offline.
  Future<Result<LookedUpStreet, AddressDirectoryFailure>> call(
    StreetLookup lookup,
  ) async {
    final StreetMatch match;
    switch (lookup) {
      case FoundStreet(match: final found):
        match = found;
      case StreetAtPoint(:final point):
        switch (await _directory.streetAt(point)) {
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value):
            match = value;
        }
    }
    final known = await _streets.findByBanId(match.id);
    // A street of the Corbeille is offered to add again: adding it brings
    // it back with its marks (`AddStreetFromMap`).
    if (known != null && !known.isDeleted) {
      return Ok(StreetOfTheTournee(match, known));
    }
    return (await _directory.numbersOf(match.id))
        .map((numbers) => StreetToAdd(match, numbers));
  }
}
