import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` (the type of a ProviderScope's overrides) lives in misc.dart.
import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/infrastructure/ban/ban_address_directory.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/geo_commune_search.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_identity.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_street_repository.dart';
import 'package:tournee_calendriers/infrastructure/system/random_id_generator.dart';
import 'package:tournee_calendriers/infrastructure/system/system_clock.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// The one HTTP client of the app, shared by the services that need the
/// network (the BAN and geo.api.gouv.fr). Riverpod calls `onDispose` when the
/// `ProviderScope` goes away, which closes the client and its connections.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Binds every port of `presentation/dependencies.dart` to its adapter, as
/// the overrides of the app's `ProviderScope`.
///
/// - [storage]: the folder of the phone storage. The streets go in
///   `streets/`, the member id in `member_id`.
/// - [addressDirectory]: replaces the BAN, so the instrumented suite can
///   import streets without the network.
/// - [communeSearch]: replaces geo.api.gouv.fr, for the same reason.
///
/// Async because the member id is read from (or first written to) the
/// phone before the first screen, so reading it later never waits.
Future<List<Override>> bindAdapters({
  required Directory storage,
  AddressDirectory? addressDirectory,
  CommuneSearch? communeSearch,
}) async {
  final ids = RandomIdGenerator();
  final identity = await LocalIdentity.load(
    File('${storage.path}${Platform.pathSeparator}member_id'),
    ids,
  );
  return [
    streetRepositoryProvider.overrideWithValue(
      LocalStreetRepository(
        Directory('${storage.path}${Platform.pathSeparator}streets'),
      ),
    ),
    addressDirectoryProvider.overrideWith(
      (ref) =>
          addressDirectory ??
          BanAddressDirectory(ref.watch(httpClientProvider)),
    ),
    communeSearchProvider.overrideWith(
      (ref) => communeSearch ?? GeoCommuneSearch(ref.watch(httpClientProvider)),
    ),
    clockProvider.overrideWithValue(const SystemClock()),
    idGeneratorProvider.overrideWithValue(ids),
    identityProvider.overrideWithValue(identity),
  ];
}
