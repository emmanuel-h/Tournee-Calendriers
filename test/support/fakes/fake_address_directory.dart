// A hand-written AddressDirectory: answers from maps given by the test and
// records each call, so an import test needs no network. An answer can be
// held back until the test releases it, to play a slow network.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

final class FakeAddressDirectory implements AddressDirectory {
  FakeAddressDirectory({
    this.communes = const {},
    this.streets = const {},
    this.places = const {},
    this.searches = const {},
  });

  /// The answer for each INSEE code; any other is not found.
  final Map<String, Result<CommuneStreets, AddressDirectoryFailure>> communes;

  /// The answer for each street; any other is not found.
  final Map<BanStreetId, Result<StreetNumbers, AddressDirectoryFailure>>
  streets;

  /// The answer for each point tapped; any other finds no street.
  final Map<GeoPoint, Result<StreetMatch, AddressDirectoryFailure>> places;

  /// The answer for each search text; any other finds nothing.
  final Map<String, Result<List<StreetMatch>, AddressDirectoryFailure>>
  searches;

  /// Every point asked, in order.
  final pointsAsked = <GeoPoint>[];

  /// Every search, in order: the text and the commune's INSEE code.
  final searchesAsked = <(String, String)>[];

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

  @override
  Future<Result<StreetMatch, AddressDirectoryFailure>> streetAt(
    GeoPoint point,
  ) async {
    pointsAsked.add(point);
    return places[point] ?? const Err(AddressDirectoryFailure.notFound);
  }

  @override
  Future<Result<List<StreetMatch>, AddressDirectoryFailure>> searchStreets(
    String text, {
    required InseeCode commune,
  }) async {
    searchesAsked.add((text, commune.value));
    return searches[text] ?? const Ok([]);
  }
}
