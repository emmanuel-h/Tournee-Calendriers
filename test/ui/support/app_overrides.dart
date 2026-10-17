// The ports the screens of the app read, bound to in-memory fakes, for
// widget tests that pump the whole app.
// `Override` (the type of a ProviderScope's overrides) lives in misc.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_notifier.dart';
import 'package:tournee_calendriers/presentation/launch/launch_place.dart';
import 'package:tournee_calendriers/presentation/new_tournee/new_tournee_notifier.dart';
import 'package:tournee_calendriers/ui/map/map_view.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_commune_search.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_moved_streets_log.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_pending_sync.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_view_preferences.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/scripted_random.dart';
import '../../support/street_fixtures.dart';
import 'fake_map_view.dart';

/// Every port the screens use, bound to [streets] (empty by default: the
/// start screen shows its first-launch state), [directory], [communes],
/// [preferences], [myTournees] (none by default), [settings] and
/// [tourneeDirectory], [tournees] (none by default), [phoneStreets] (the
/// streets kept on the phone since M1, none by default: no card offers
/// them to a tournée), [movedStreets] and [pending] (nothing waiting to be
/// sent by default); [member] (Léa by
/// default) uses the phone and marks the houses at [now] (two o'clock by
/// default); [account] is the phone's account (none by default, and no
/// network to get one); [admins] says whether the phone, and which
/// members, are admins of the app (none by default). The commune search and the duplicate check of
/// « Nouvelle tournée » answer without waiting for a pause in the typing;
/// a new join code is `234567`. Maps are [FakeMapView]s: a native map
/// cannot run in a widget test.
///
/// The app opens on the start screen, as on a phone that already holds
/// streets or tournées; with [chooseLaunch], it decides from the fakes as
/// at a real launch (« Bienvenue » on an empty phone).
List<Override> fakePhone({
  FakeStreetRepository? streets,
  FakeAddressDirectory? directory,
  FakeCommuneSearch? communes,
  FakeStreetViewPreferences? preferences,
  FakeMyTourneesStore? myTournees,
  FakePhoneSettings? settings,
  FakeTourneeDirectory? tourneeDirectory,
  FakeTourneeRepository? tournees,
  FakeStreetRepository? phoneStreets,
  FakeMovedStreetsLog? movedStreets,
  FakePendingSync? pending,
  MemberId? member,
  DateTime? now,
  FakeMemberAccount? account,
  FakeAdminStatus? admins,
  bool chooseLaunch = false,
}) => [
  if (!chooseLaunch)
    launchPlaceProvider.overrideWithValue(const AsyncData(LaunchOnStreets())),
  duplicateCheckDelayProvider.overrideWithValue(Duration.zero),
  tourneeMapViewProvider.overrideWithValue(FakeMapView.new),
  streetRepositoryProvider.overrideWithValue(streets ?? FakeStreetRepository()),
  phoneStreetRepositoryProvider.overrideWithValue(
    phoneStreets ?? FakeStreetRepository(),
  ),
  movedStreetsLogProvider.overrideWithValue(
    movedStreets ?? FakeMovedStreetsLog(),
  ),
  pendingSyncProvider.overrideWithValue(pending ?? FakePendingSync()),
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
  memberAccountProvider.overrideWithValue(account ?? FakeMemberAccount()),
  tourneeRepositoryProvider.overrideWithValue(
    tournees ?? FakeTourneeRepository(),
  ),
  adminStatusProvider.overrideWithValue(admins ?? FakeAdminStatus()),
  // The indexes of `2`…`7` in the code alphabet: the code `234567`.
  randomProvider.overrideWithValue(ScriptedRandom([23, 24, 25, 26, 27, 28])),
];

/// No street on the phone, no network service needed.
List<Override> emptyPhone() => fakePhone();
