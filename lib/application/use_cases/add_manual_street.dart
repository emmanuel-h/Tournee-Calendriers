import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// « Ajouter la rue » of « Rue à la main » (PLAN §5.5): a street the map
/// does not have (a private road, a new estate), typed in. Needs no
/// network.
///
/// The street has no BAN id and no shape: it shows in the lists, not as a
/// line on the map.
final class AddManualStreet {
  const AddManualStreet(this._streets, this._ids);

  final StreetRepository _streets;
  final IdGenerator _ids;

  /// Stores the street [name] of [commune] with a house to do for each of
  /// [numbers] (usually from `manualStreetNumbers`), and returns it.
  Future<Street> call({
    required StreetName name,
    required Commune commune,
    required Iterable<HouseNumber> numbers,
  }) async {
    final street = Street.manual(
      id: StreetId(_ids.newId()),
      name: name,
      commune: commune,
      numbers: numbers,
    );
    await _streets.add(street);
    return street;
  }
}
