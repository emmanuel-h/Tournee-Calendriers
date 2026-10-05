// A hand-written AddressDirectory: answers from maps given by the test and
// records each call, so an import test needs no network. An answer can be
// held back until the test releases it, to play a slow network.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
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

  /// The calls whose answer waits until the test completes the completer.
  final _heldCommunes = <String, Completer<void>>{};
  final _heldStreets = <BanStreetId, Completer<void>>{};

  /// Makes the next listing of [inseeCode] wait until [releaseCommune].
  void holdCommune(String inseeCode) => _heldCommunes[inseeCode] = Completer();
  void releaseCommune(String inseeCode) =>
      _heldCommunes.remove(inseeCode)!.complete();

  /// Makes the next numbers of [street] wait until [releaseStreet].
  void holdStreet(BanStreetId street) => _heldStreets[street] = Completer();
  void releaseStreet(BanStreetId street) =>
      _heldStreets.remove(street)!.complete();

  @override
  Future<Result<CommuneStreets, AddressDirectoryFailure>> streetsOf(
    InseeCode inseeCode,
  ) async {
    // Keyed by the text of the code, so a test writes `'69264'`.
    final code = inseeCode.value;
    communesAsked.add(code);
    await _heldCommunes[code]?.future;
    return communes[code] ?? const Err(AddressDirectoryFailure.notFound);
  }

  @override
  Future<Result<StreetNumbers, AddressDirectoryFailure>> numbersOf(
    BanStreetId street,
  ) async {
    streetsAsked.add(street);
    await _heldStreets[street]?.future;
    return streets[street] ?? const Err(AddressDirectoryFailure.notFound);
  }
}
