import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// The streets of a commune as the BAN lists them, for the import screen to
/// show and let the user choose (« Importer toute la commune » or a
/// selection). Needs the network.
final class ListCommuneStreets {
  const ListCommuneStreets(this._directory);

  final AddressDirectory _directory;

  /// The streets of the commune [inseeCode] (`69264`).
  Future<Result<CommuneStreets, AddressDirectoryFailure>> call(
    InseeCode inseeCode,
  ) => _directory.streetsOf(inseeCode);
}
