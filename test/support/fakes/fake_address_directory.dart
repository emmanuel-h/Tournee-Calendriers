// A hand-written AddressDirectory: answers from maps given by the test and
// records each call, so an import test needs no network.
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

final class FakeAddressDirectory implements AddressDirectory {
  FakeAddressDirectory({this.communes = const {}, this.streets = const {}});

  /// The answer for each INSEE code; any other is not found.
  final Map<String, Result<CommuneStreets, AddressDirectoryFailure>> communes;

  /// The answer for each street; any other is not found.
  final Map<BanStreetId, Result<StreetNumbers, AddressDirectoryFailure>>
  streets;

  /// Every INSEE code asked, in order.
  final communesAsked = <String>[];

  /// Every street asked, in order.
  final streetsAsked = <BanStreetId>[];

  @override
  Future<Result<CommuneStreets, AddressDirectoryFailure>> streetsOf(
    String inseeCode,
  ) async {
    communesAsked.add(inseeCode);
    return communes[inseeCode] ?? const Err(AddressDirectoryFailure.notFound);
  }

  @override
  Future<Result<StreetNumbers, AddressDirectoryFailure>> numbersOf(
    BanStreetId street,
  ) async {
    streetsAsked.add(street);
    return streets[street] ?? const Err(AddressDirectoryFailure.notFound);
  }
}
