/// The Riverpod providers that hand the use cases to the notifiers of
/// `presentation/`, and the ports those use cases need.
///
/// A provider is a global, lazily built value that a notifier reads with
/// `ref.watch(markHouseProvider)`. The **ports** are declared here, where
/// the layer rules let `presentation/` see them, but have no adapter here:
/// `presentation/` must not import `infrastructure/`. The composition root
/// (`bootstrap/`) binds each one to its adapter by *overriding* it in the
/// `ProviderScope`; tests override them with fakes the same way. Reading a
/// port nobody bound fails at once, naming it.
library;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/moved_streets_log.dart';
import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/application/ports/pending_sync.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/application/ports/street_view_preferences.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/application/use_cases/find_imported_streets.dart';
import 'package:tournee_calendriers/application/use_cases/hide_done.dart';
import 'package:tournee_calendriers/application/use_cases/import_reference_area.dart';
import 'package:tournee_calendriers/application/use_cases/list_commune_streets.dart';
import 'package:tournee_calendriers/application/use_cases/mark_dwelling.dart';
import 'package:tournee_calendriers/application/use_cases/mark_house.dart';
import 'package:tournee_calendriers/application/use_cases/move_streets_into_tournee.dart';
import 'package:tournee_calendriers/application/use_cases/my_tournees.dart';
import 'package:tournee_calendriers/application/use_cases/observe_corbeille.dart';
import 'package:tournee_calendriers/application/use_cases/observe_pending_sync.dart';
import 'package:tournee_calendriers/application/use_cases/observe_street.dart';
import 'package:tournee_calendriers/application/use_cases/observe_streets.dart';
import 'package:tournee_calendriers/application/use_cases/phone_settings.dart';
import 'package:tournee_calendriers/application/use_cases/search_communes.dart';
import 'package:tournee_calendriers/application/use_cases/set_house_details.dart';
import 'package:tournee_calendriers/application/use_cases/sign_in.dart';
import 'package:tournee_calendriers/application/use_cases/team.dart';
import 'package:tournee_calendriers/application/use_cases/undo_last_change.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_repository.dart';

// Ports, bound by bootstrap/.

/// The streets every street use case works on: those of the open
/// tournée, or the phone's own (M1) while none is open. The composition
/// root makes it follow the open tournée, so every use case, and every
/// screen that watches one, follows a switch of tournée by itself.
final streetRepositoryProvider = Provider<StreetRepository>(
  (ref) => _unbound('StreetRepository'),
);

/// The streets kept on the phone since M1, whichever tournée is open: what
/// « Les ajouter à la tournée » moves (PLAN §5.0).
final phoneStreetRepositoryProvider = Provider<StreetRepository>(
  (ref) => _unbound('phone StreetRepository'),
);

/// What the open tournée's streets still have to send to the server. The
/// composition root binds it to the same adapter as
/// [streetRepositoryProvider], so one listener serves both; with no
/// tournée open there is nothing to send.
final pendingSyncProvider = Provider<PendingSync>(
  (ref) => _unbound('PendingSync'),
);
final addressDirectoryProvider = Provider<AddressDirectory>(
  (ref) => _unbound('AddressDirectory'),
);
final communeSearchProvider = Provider<CommuneSearch>(
  (ref) => _unbound('CommuneSearch'),
);
final clockProvider = Provider<Clock>((ref) => _unbound('Clock'));
final idGeneratorProvider = Provider<IdGenerator>(
  (ref) => _unbound('IdGenerator'),
);
final identityProvider = Provider<IdentityProvider>(
  (ref) => _unbound('IdentityProvider'),
);
final streetViewPreferencesProvider = Provider<StreetViewPreferences>(
  (ref) => _unbound('StreetViewPreferences'),
);
final memberAccountProvider = Provider<MemberAccount>(
  (ref) => _unbound('MemberAccount'),
);
final myTourneesStoreProvider = Provider<MyTourneesStore>(
  (ref) => _unbound('MyTourneesStore'),
);
final phoneSettingsProvider = Provider<PhoneSettings>(
  (ref) => _unbound('PhoneSettings'),
);
final tourneeDirectoryProvider = Provider<TourneeDirectory>(
  (ref) => _unbound('TourneeDirectory'),
);
final tourneeRepositoryProvider = Provider<TourneeRepository>(
  (ref) => _unbound('TourneeRepository'),
);
final movedStreetsLogProvider = Provider<MovedStreetsLog>(
  (ref) => _unbound('MovedStreetsLog'),
);

/// The source join codes are drawn from: `Random.secure()` in the app
/// (PLAN §5.2), a scripted one in tests. `Random` (`dart:math`) is an
/// interface, so it is bound like a port.
final randomProvider = Provider<Random>((ref) => _unbound('Random'));

/// `Never`: this function never returns, it always throws, so it can stand
/// where a port is expected.
Never _unbound(String port) => throw StateError(
  '$port has no adapter: bind it in bootstrap/ (or a test override).',
);

// Use cases. `ref.watch` (not `ref.read`) ties each use case to its ports:
// should a port be replaced, the use case is built again with the new one.

final observeStreetProvider = Provider(
  (ref) => ObserveStreet(ref.watch(streetRepositoryProvider)),
);
final observeStreetsProvider = Provider(
  (ref) => ObserveStreets(ref.watch(streetRepositoryProvider)),
);
final markHouseProvider = Provider(
  (ref) => MarkHouse(
    ref.watch(streetRepositoryProvider),
    ref.watch(clockProvider),
    ref.watch(identityProvider),
  ),
);
final setHouseDetailsProvider = Provider(
  (ref) => SetHouseDetails(
    ref.watch(streetRepositoryProvider),
    ref.watch(clockProvider),
    ref.watch(identityProvider),
  ),
);
final markDwellingProvider = Provider(
  (ref) => MarkDwelling(
    ref.watch(streetRepositoryProvider),
    ref.watch(clockProvider),
    ref.watch(identityProvider),
  ),
);
final describeBuildingProvider = Provider(
  (ref) => DescribeBuilding(
    ref.watch(streetRepositoryProvider),
    ref.watch(clockProvider),
    ref.watch(identityProvider),
  ),
);
final editStreetNumbersProvider = Provider(
  (ref) => EditStreetNumbers(
    ref.watch(streetRepositoryProvider),
    ref.watch(clockProvider),
    ref.watch(identityProvider),
  ),
);
final undoLastChangeProvider = Provider(
  (ref) => UndoLastChange(ref.watch(streetRepositoryProvider)),
);
final listCommuneStreetsProvider = Provider(
  (ref) => ListCommuneStreets(ref.watch(addressDirectoryProvider)),
);
final importReferenceAreaProvider = Provider(
  (ref) => ImportReferenceArea(
    ref.watch(addressDirectoryProvider),
    ref.watch(streetRepositoryProvider),
    ref.watch(idGeneratorProvider),
  ),
);
final searchCommunesProvider = Provider(
  (ref) => SearchCommunes(ref.watch(communeSearchProvider)),
);
final findImportedStreetsProvider = Provider(
  (ref) => FindImportedStreets(ref.watch(streetRepositoryProvider)),
);
final readHideDoneProvider = Provider(
  (ref) => ReadHideDone(ref.watch(streetViewPreferencesProvider)),
);
final saveHideDoneProvider = Provider(
  (ref) => SaveHideDone(ref.watch(streetViewPreferencesProvider)),
);
final readSignedInMemberProvider = Provider(
  (ref) => ReadSignedInMember(ref.watch(memberAccountProvider)),
);
final signInProvider = Provider(
  (ref) => SignIn(ref.watch(memberAccountProvider)),
);
final readMyTourneesProvider = Provider(
  (ref) => ReadMyTournees(ref.watch(myTourneesStoreProvider)),
);
final observeMyTourneesProvider = Provider(
  (ref) => ObserveMyTournees(ref.watch(myTourneesStoreProvider)),
);
final openTourneeProvider = Provider(
  (ref) => OpenTournee(ref.watch(myTourneesStoreProvider)),
);
final watchJoinRequestProvider = Provider(
  (ref) => WatchJoinRequest(
    ref.watch(tourneeDirectoryProvider),
    ref.watch(memberAccountProvider),
  ),
);
final settleJoinRequestProvider = Provider(
  (ref) => SettleJoinRequest(ref.watch(myTourneesStoreProvider)),
);
final readPhoneSettingsProvider = Provider(
  (ref) => ReadPhoneSettings(ref.watch(phoneSettingsProvider)),
);
final changeMemberNameProvider = Provider(
  (ref) => ChangeMemberName(ref.watch(phoneSettingsProvider)),
);
final chooseThemeProvider = Provider(
  (ref) => ChooseTheme(ref.watch(phoneSettingsProvider)),
);
final observeCorbeilleProvider = Provider(
  (ref) => ObserveCorbeille(ref.watch(streetRepositoryProvider)),
);
final observePendingSyncProvider = Provider(
  (ref) => ObservePendingSync(ref.watch(pendingSyncProvider)),
);
final observeTeamProvider = Provider(
  (ref) => ObserveTeam(ref.watch(tourneeRepositoryProvider)),
);
final readCurrentMemberProvider = Provider(
  (ref) => ReadCurrentMember(ref.watch(identityProvider)),
);
final acceptMemberProvider = Provider(
  (ref) => AcceptMember(
    ref.watch(tourneeRepositoryProvider),
    ref.watch(clockProvider),
    ref.watch(identityProvider),
  ),
);
final refuseMemberProvider = Provider(
  (ref) => RefuseMember(
    ref.watch(tourneeRepositoryProvider),
    ref.watch(identityProvider),
  ),
);
final removeMemberProvider = Provider(
  (ref) => RemoveMember(
    ref.watch(tourneeRepositoryProvider),
    ref.watch(identityProvider),
  ),
);
final leaveTourneeProvider = Provider(
  (ref) => LeaveTournee(
    ref.watch(tourneeRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(myTourneesStoreProvider),
  ),
);
final regenerateJoinCodeProvider = Provider(
  (ref) => RegenerateJoinCode(
    ref.watch(tourneeRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(randomProvider),
  ),
);
final deleteTourneeProvider = Provider(
  (ref) => DeleteTournee(
    ref.watch(tourneeRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(myTourneesStoreProvider),
  ),
);
final countStreetsToMoveProvider = Provider(
  (ref) => CountStreetsToMove(
    ref.watch(phoneStreetRepositoryProvider),
    ref.watch(movedStreetsLogProvider),
    ref.watch(tourneeRepositoryProvider),
    ref.watch(identityProvider),
  ),
);
final moveStreetsIntoTourneeProvider = Provider(
  (ref) => MoveStreetsIntoTournee(
    ref.watch(phoneStreetRepositoryProvider),
    ref.watch(streetRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(movedStreetsLogProvider),
  ),
);
