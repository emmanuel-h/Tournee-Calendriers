// The ports the screens of the app read, bound to in-memory fakes, for
// widget tests that pump the whole app.
// `Override` (the type of a ProviderScope's overrides) lives in misc.dart.
import 'package:flutter_riverpod/misc.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_notifier.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_commune_search.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_view_preferences.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/scripted_random.dart';
import '../../support/street_fixtures.dart';

/// Every port the screens use, bound to [streets] (empty by default: the
/// start screen shows its first-launch state), [directory], [communes],
/// [preferences], [myTournees] (none by default), [settings] and
/// [tourneeDirectory], [tournees] (none by default); [member] (Léa by
/// default) uses the phone and marks the houses at [now] (two o'clock by
/// default). The commune search answers without waiting for a pause in
/// the typing; a new join code is `234567`.
List<Override> fakePhone({
  FakeStreetRepository? streets,
  FakeAddressDirectory? directory,
  FakeCommuneSearch? communes,
  FakeStreetViewPreferences? preferences,
  FakeMyTourneesStore? myTournees,
  FakePhoneSettings? settings,
  FakeTourneeDirectory? tourneeDirectory,
  FakeTourneeRepository? tournees,
  MemberId? member,
  DateTime? now,
}) => [
  streetRepositoryProvider.overrideWithValue(streets ?? FakeStreetRepository()),
  addressDirectoryProvider.overrideWithValue(
    directory ?? FakeAddressDirectory(),
  ),
  communeSearchProvider.overrideWithValue(communes ?? FakeCommuneSearch()),
  idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
  clockProvider.overrideWithValue(FakeClock(now ?? twoPm)),
  identityProvider.overrideWithValue(FakeIdentity(member ?? lea)),
  streetViewPreferencesProvider.overrideWithValue(
    preferences ?? FakeStreetViewPreferences(),
  ),
  communeSearchDelayProvider.overrideWithValue(Duration.zero),
  myTourneesStoreProvider.overrideWithValue(
    myTournees ?? FakeMyTourneesStore(),
  ),
  phoneSettingsProvider.overrideWithValue(settings ?? FakePhoneSettings()),
  tourneeDirectoryProvider.overrideWithValue(
    tourneeDirectory ?? FakeTourneeDirectory(),
  ),
  memberAccountProvider.overrideWithValue(FakeMemberAccount()),
  tourneeRepositoryProvider.overrideWithValue(
    tournees ?? FakeTourneeRepository(),
  ),
  // The indexes of `2`…`7` in the code alphabet: the code `234567`.
  randomProvider.overrideWithValue(ScriptedRandom([23, 24, 25, 26, 27, 28])),
];

/// No street on the phone, no network service needed.
List<Override> emptyPhone() => fakePhone();
