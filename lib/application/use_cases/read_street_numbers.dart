import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

/// The numbers of a BAN street not added yet, with their positions: what
/// « Partie de la rue » chooses among from a row of « Liste » (PLAN §5.15).
/// Needs the network.
final class ReadStreetNumbers {
  const ReadStreetNumbers(this._directory);

  final AddressDirectory _directory;

  /// The numbers of the BAN street [street];
  /// [AddressDirectoryFailure.noNetwork] offline.
  Future<Result<StreetNumbers, AddressDirectoryFailure>> call(
    BanStreetId street,
  ) => _directory.numbersOf(street);
}
