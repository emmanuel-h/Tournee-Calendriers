import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// The Rue screen's source (PLAN §5.6): the street now, then again after
/// each change, made on this phone or (from M2) by a teammate. Works
/// offline: it reads what the phone holds.
final class ObserveStreet {
  const ObserveStreet(this._streets);

  final StreetRepository _streets;

  /// The street [streetId]; null while there is no such street (it was
  /// never imported, or the id is stale).
  Stream<Street?> call(StreetId streetId) => _streets.watch(streetId);
}
