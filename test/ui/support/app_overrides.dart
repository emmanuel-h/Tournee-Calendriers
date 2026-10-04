// The ports the screens of the app read, bound to in-memory fakes, for
// widget tests that pump the whole app.
// `Override` (the type of a ProviderScope's overrides) lives in misc.dart.
import 'package:flutter_riverpod/misc.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_notifier.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_commune_search.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';

/// Every port the start and import screens use, bound to [streets] (empty
/// by default: the start screen shows its first-launch state), [directory]
/// and [communes]. The commune search answers without waiting for a pause
/// in the typing.
List<Override> fakePhone({
  FakeStreetRepository? streets,
  FakeAddressDirectory? directory,
  FakeCommuneSearch? communes,
}) => [
  streetRepositoryProvider.overrideWithValue(streets ?? FakeStreetRepository()),
  addressDirectoryProvider.overrideWithValue(
    directory ?? FakeAddressDirectory(),
  ),
  communeSearchProvider.overrideWithValue(communes ?? FakeCommuneSearch()),
  idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
  communeSearchDelayProvider.overrideWithValue(Duration.zero),
];

/// No street on the phone, no network service needed.
List<Override> emptyPhone() => fakePhone();
