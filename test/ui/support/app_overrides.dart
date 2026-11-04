// The ports the screens of the app read, bound to in-memory fakes, for
// widget tests that pump the whole app.
// `Override` (the type of a ProviderScope's overrides) lives in misc.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_notifier.dart';
import 'package:tournee_calendriers/presentation/launch/launch_place.dart';
import 'package:tournee_calendriers/presentation/new_sector/new_sector_notifier.dart';
import 'package:tournee_calendriers/ui/map/map_view.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show team;
import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_commune_search.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_pending_sync.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/fakes/fake_sector_directory.dart';
import '../../support/fakes/fake_sector_downloads.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_server_connection.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
import '../../support/fakes/fake_street_view_preferences.dart';
import '../../support/results.dart';
import '../../support/scripted_random.dart';
import '../../support/street_fixtures.dart';
import 'fake_map_view.dart';

/// Every port the screens use, bound to [streets] (empty by default), [directory], [shapes] (no
/// road known by default), [communes],
/// [preferences], [mySectors] (none by default), [settings] and
/// [sectorDirectory], [sectors] (none by default), [pending] (nothing
/// waiting to be sent by default), [connection] (online by default), [downloads] (no
/// tournée downloaded by default), [rounds] (no tournée on by default)
/// and [ledger] (no tournée validated by default);
/// [member] (Léa by
/// default) uses the phone and marks the houses at [now] (two o'clock by
/// default), or on [clock], which a test may move; [account] is the phone's account (none by default, and no
/// network to get one); [admins] says whether the phone, and which
/// members, are admins of the app (none by default). The commune search and the duplicate check of
/// « Nouveau secteur » answer without waiting for a pause in the typing;
/// a new join code is `234567`. Maps are [FakeMapView]s: a native map
/// cannot run in a widget test. With [nativeMap], they are the real
/// MapLibre maps, for the store screenshots run on a device
/// (`integration_test/store_screenshots_test.dart`).
///
/// The app opens on the start screen, as on a phone that already knows
/// secteurs; with [chooseLaunch], it decides from the fakes as
/// at a real launch (« Bienvenue » on an empty phone).
List<Override> fakePhone({
  FakeStreetRepository? streets,
  FakeAddressDirectory? directory,
  FakeStreetShapes? shapes,
  FakeCommuneSearch? communes,
  FakeStreetViewPreferences? preferences,
  FakeMySectorsStore? mySectors,
  FakePhoneSettings? settings,
  FakeSectorDirectory? sectorDirectory,
  FakeSectorRepository? sectors,
  FakePendingSync? pending,
  FakeServerConnection? connection,
  FakeSectorDownloads? downloads,
  FakeOpenRoundStore? rounds,
  RoundLedger? ledger,
  MemberId? member,
  DateTime? now,
  FakeClock? clock,
  FakeMemberAccount? account,
  FakeAdminStatus? admins,
  bool chooseLaunch = false,
  bool nativeMap = false,
}) => [
  if (!chooseLaunch)
    launchPlaceProvider.overrideWithValue(const AsyncData(LaunchOnStreets())),
  duplicateCheckDelayProvider.overrideWithValue(Duration.zero),
  if (!nativeMap) sectorMapViewProvider.overrideWithValue(FakeMapView.new),
  streetRepositoryProvider.overrideWithValue(streets ?? FakeStreetRepository()),
  pendingSyncProvider.overrideWithValue(pending ?? FakePendingSync()),
  serverConnectionProvider.overrideWithValue(
    connection ?? FakeServerConnection(),
  ),
  sectorDownloadsProvider.overrideWithValue(downloads ?? FakeSectorDownloads()),
  addressDirectoryProvider.overrideWithValue(
    directory ?? FakeAddressDirectory(),
  ),
  streetShapesProvider.overrideWithValue(shapes ?? FakeStreetShapes()),
  communeSearchProvider.overrideWithValue(communes ?? FakeCommuneSearch()),
  idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
  clockProvider.overrideWithValue(clock ?? FakeClock(now ?? twoPm)),
  identityProvider.overrideWithValue(FakeIdentity(member ?? lea)),
  streetViewPreferencesProvider.overrideWithValue(
    preferences ?? FakeStreetViewPreferences(),
  ),
  communeSearchDelayProvider.overrideWithValue(Duration.zero),
  mySectorsStoreProvider.overrideWithValue(mySectors ?? FakeMySectorsStore()),
  phoneSettingsProvider.overrideWithValue(settings ?? FakePhoneSettings()),
  openRoundStoreProvider.overrideWithValue(rounds ?? FakeOpenRoundStore()),
  roundLedgerProvider.overrideWithValue(ledger ?? FakeRoundLedger()),
  sectorDirectoryProvider.overrideWithValue(
    sectorDirectory ?? FakeSectorDirectory(),
  ),
  memberAccountProvider.overrideWithValue(account ?? FakeMemberAccount()),
  sectorRepositoryProvider.overrideWithValue(sectors ?? FakeSectorRepository()),
  adminStatusProvider.overrideWithValue(admins ?? FakeAdminStatus()),
  // The indexes of `2`…`7` in the code alphabet: the code `234567`.
  randomProvider.overrideWithValue(ScriptedRandom([23, 24, 25, 26, 27, 28])),
];

/// [fakePhone] with the 49 open, Léa in its team, and its tournée on:
/// [rounds] (a tournée started at [startedAt], nothing in it yet, by
/// default). Houses are marked only during a tournée (PLAN §5.14), so this
/// is the phone of the tests that tap a house or a door.
List<Override> fakePhoneInRound({
  FakeStreetRepository? streets,
  FakeStreetViewPreferences? preferences,
  FakeOpenRoundStore? rounds,
  FakeClock? clock,
}) => fakePhone(
  streets: streets,
  preferences: preferences,
  clock: clock,
  rounds: rounds ?? FakeOpenRoundStore(newRound()),
  sectors: FakeSectorRepository([team()]),
  mySectors: FakeMySectorsStore(
    valueOf(MySectors.none.remember(sector49).open(sector49.id)),
  ),
);

/// No street on the phone, no network service needed.
List<Override> emptyPhone() => fakePhone();
