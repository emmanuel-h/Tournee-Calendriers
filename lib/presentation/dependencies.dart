/// The Riverpod providers that hand the use cases to the notifiers of
/// `presentation/`, and the ports those use cases need.
///
/// A provider is a global, lazily built value that a notifier reads with
/// `ref.watch(setHouseDetailsProvider)`. The **ports** are declared here, where
/// the layer rules let `presentation/` see them, but have no adapter here:
/// `presentation/` must not import `infrastructure/`. The composition root
/// (`bootstrap/`) binds each one to its adapter by *overriding* it in the
/// `ProviderScope`; tests override them with fakes the same way. Reading a
/// port nobody bound fails at once, naming it.
library;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/admin_status.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/moved_streets_log.dart';
import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/application/ports/pending_sync.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/application/ports/sector_downloads.dart';
import 'package:tournee_calendriers/application/ports/server_connection.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/application/ports/street_view_preferences.dart';
import 'package:tournee_calendriers/application/ports/streets_download.dart';
import 'package:tournee_calendriers/application/use_cases/add_manual_street.dart';
import 'package:tournee_calendriers/application/use_cases/add_street_from_map.dart';
import 'package:tournee_calendriers/application/use_cases/admins.dart';
import 'package:tournee_calendriers/application/use_cases/choose_start_point.dart';
import 'package:tournee_calendriers/application/use_cases/create_sector.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/application/use_cases/download_sector.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/application/use_cases/fill_street_shape.dart';
import 'package:tournee_calendriers/application/use_cases/find_imported_streets.dart';
import 'package:tournee_calendriers/application/use_cases/hide_done.dart';
import 'package:tournee_calendriers/application/use_cases/import_reference_area.dart';
import 'package:tournee_calendriers/application/use_cases/join_sector.dart';
import 'package:tournee_calendriers/application/use_cases/list_commune_streets.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street_shape.dart';
import 'package:tournee_calendriers/application/use_cases/mark_dwelling.dart';
import 'package:tournee_calendriers/application/use_cases/move_streets_into_sector.dart';
import 'package:tournee_calendriers/application/use_cases/my_sectors.dart';
import 'package:tournee_calendriers/application/use_cases/observe_corbeille.dart';
import 'package:tournee_calendriers/application/use_cases/observe_my_streets.dart';
import 'package:tournee_calendriers/application/use_cases/observe_offline.dart';
import 'package:tournee_calendriers/application/use_cases/observe_pending_sync.dart';
import 'package:tournee_calendriers/application/use_cases/observe_street.dart';
import 'package:tournee_calendriers/application/use_cases/observe_streets.dart';
import 'package:tournee_calendriers/application/use_cases/observe_streets_by_member.dart';
import 'package:tournee_calendriers/application/use_cases/phone_settings.dart';
import 'package:tournee_calendriers/application/use_cases/purge_corbeille.dart';
import 'package:tournee_calendriers/application/use_cases/refresh_offline_maps.dart';
import 'package:tournee_calendriers/application/use_cases/search_communes.dart';
import 'package:tournee_calendriers/application/use_cases/search_street.dart';
import 'package:tournee_calendriers/application/use_cases/sector_downloads.dart';
import 'package:tournee_calendriers/application/use_cases/set_house_details.dart';
import 'package:tournee_calendriers/application/use_cases/sign_in.dart';
import 'package:tournee_calendriers/application/use_cases/street_assignment.dart';
import 'package:tournee_calendriers/application/use_cases/team.dart';
import 'package:tournee_calendriers/application/use_cases/undo_last_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_repository.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

// Ports, bound by bootstrap/.

/// The streets every street use case works on: those of the open
/// tournée, or the phone's own (M1) while none is open. The composition
/// root makes it follow the open tournée, so every use case, and every
/// screen that watches one, follows a switch of tournée by itself.
final streetRepositoryProvider = Provider<StreetRepository>(
  (ref) => _unbound('StreetRepository'),
);

/// The streets kept on the phone since M1, whichever tournée is open: what
/// « Les ajouter au secteur » moves (PLAN §5.0).
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

/// Whether the phone reaches the server. The composition root binds it to
/// the same adapter as [streetRepositoryProvider] too: the open tournée's
/// listener tells it; with no tournée open, nothing does.
final serverConnectionProvider = Provider<ServerConnection>(
  (ref) => _unbound('ServerConnection'),
);
final addressDirectoryProvider = Provider<AddressDirectory>(
  (ref) => _unbound('AddressDirectory'),
);
final communeSearchProvider = Provider<CommuneSearch>(
  (ref) => _unbound('CommuneSearch'),
);
final streetShapesProvider = Provider<StreetShapes>(
  (ref) => _unbound('StreetShapes'),
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
final mySectorsStoreProvider = Provider<MySectorsStore>(
  (ref) => _unbound('MySectorsStore'),
);
final phoneSettingsProvider = Provider<PhoneSettings>(
  (ref) => _unbound('PhoneSettings'),
);
final sectorDirectoryProvider = Provider<SectorDirectory>(
  (ref) => _unbound('SectorDirectory'),
);
final sectorRepositoryProvider = Provider<SectorRepository>(
  (ref) => _unbound('SectorRepository'),
);
final movedStreetsLogProvider = Provider<MovedStreetsLog>(
  (ref) => _unbound('MovedStreetsLog'),
);
final adminStatusProvider = Provider<AdminStatus>(
  (ref) => _unbound('AdminStatus'),
);

/// The streets of a tournée as the server has them, for its download
/// (PLAN §7).
final streetsDownloadProvider = Provider<StreetsDownload>(
  (ref) => _unbound('StreetsDownload'),
);

/// The map regions kept on the phone for offline use.
final offlineMapStoreProvider = Provider<OfflineMapStore>(
  (ref) => _unbound('OfflineMapStore'),
);

/// The tournées downloaded on this phone, when, and how much.
final sectorDownloadsProvider = Provider<SectorDownloads>(
  (ref) => _unbound('SectorDownloads'),
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
final observeMyStreetsProvider = Provider(
  (ref) => ObserveMyStreets(
    ref.watch(streetRepositoryProvider),
    ref.watch(identityProvider),
  ),
);
final observeStreetsByMemberProvider = Provider(
  (ref) => ObserveStreetsByMember(ref.watch(streetRepositoryProvider)),
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
final takeStreetProvider = Provider(
  (ref) => TakeStreet(
    ref.watch(streetRepositoryProvider),
    ref.watch(identityProvider),
  ),
);
final releaseStreetProvider = Provider(
  (ref) => ReleaseStreet(
    ref.watch(streetRepositoryProvider),
    ref.watch(identityProvider),
  ),
);
final lookUpStreetProvider = Provider(
  (ref) => LookUpStreet(
    ref.watch(addressDirectoryProvider),
    ref.watch(streetRepositoryProvider),
  ),
);
final addStreetFromMapProvider = Provider(
  (ref) => AddStreetFromMap(
    ref.watch(streetRepositoryProvider),
    ref.watch(idGeneratorProvider),
    ref.watch(identityProvider),
  ),
);
final lookUpStreetShapeProvider = Provider(
  (ref) => LookUpStreetShape(ref.watch(streetShapesProvider)),
);
final fillStreetShapeProvider = Provider(
  (ref) => FillStreetShape(
    ref.watch(streetShapesProvider),
    ref.watch(streetRepositoryProvider),
  ),
);
final addManualStreetProvider = Provider(
  (ref) => AddManualStreet(
    ref.watch(streetRepositoryProvider),
    ref.watch(idGeneratorProvider),
    ref.watch(identityProvider),
  ),
);
final searchStreetProvider = Provider(
  (ref) => SearchStreet(ref.watch(addressDirectoryProvider)),
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
final observeSignInProvider = Provider(
  (ref) => ObserveSignIn(ref.watch(memberAccountProvider)),
);
final readMySectorsProvider = Provider(
  (ref) => ReadMySectors(ref.watch(mySectorsStoreProvider)),
);
final observeMySectorsProvider = Provider(
  (ref) => ObserveMySectors(ref.watch(mySectorsStoreProvider)),
);
final openSectorProvider = Provider(
  (ref) => OpenSector(ref.watch(mySectorsStoreProvider)),
);
final watchJoinRequestProvider = Provider(
  (ref) => WatchJoinRequest(
    ref.watch(sectorDirectoryProvider),
    ref.watch(memberAccountProvider),
  ),
);
final settleJoinRequestProvider = Provider(
  (ref) => SettleJoinRequest(ref.watch(mySectorsStoreProvider)),
);
final watchMembershipProvider = Provider(
  (ref) => WatchMembership(
    ref.watch(sectorDirectoryProvider),
    ref.watch(memberAccountProvider),
  ),
);
final watchOwnNameProvider = Provider(
  (ref) => WatchOwnName(
    ref.watch(sectorDirectoryProvider),
    ref.watch(memberAccountProvider),
  ),
);
final forgetLostSectorProvider = Provider(
  (ref) => ForgetLostSector(ref.watch(mySectorsStoreProvider)),
);
final readPhoneSettingsProvider = Provider(
  (ref) => ReadPhoneSettings(ref.watch(phoneSettingsProvider)),
);
final changeMemberNameProvider = Provider(
  (ref) => ChangeMemberName(
    ref.watch(phoneSettingsProvider),
    ref.watch(sectorRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(mySectorsStoreProvider),
  ),
);
final catchUpMemberNameProvider = Provider(
  (ref) => CatchUpMemberName(
    ref.watch(phoneSettingsProvider),
    ref.watch(sectorRepositoryProvider),
    ref.watch(identityProvider),
  ),
);
final chooseThemeProvider = Provider(
  (ref) => ChooseTheme(ref.watch(phoneSettingsProvider)),
);
final observeCorbeilleProvider = Provider(
  (ref) => ObserveCorbeille(ref.watch(streetRepositoryProvider)),
);
final purgeCorbeilleProvider = Provider(
  (ref) => PurgeCorbeille(
    ref.watch(streetRepositoryProvider),
    ref.watch(clockProvider),
  ),
);
final observePendingSyncProvider = Provider(
  (ref) => ObservePendingSync(ref.watch(pendingSyncProvider)),
);
final observeOfflineProvider = Provider(
  (ref) => ObserveOffline(ref.watch(serverConnectionProvider)),
);
final observeTeamProvider = Provider(
  (ref) => ObserveTeam(ref.watch(sectorRepositoryProvider)),
);
final observeSectorCommunesProvider = Provider(
  (ref) => ObserveSectorCommunes(ref.watch(sectorRepositoryProvider)),
);
final addCommuneProvider = Provider(
  (ref) => AddCommune(
    ref.watch(sectorRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(adminStatusProvider),
  ),
);
final removeCommuneProvider = Provider(
  (ref) => RemoveCommune(
    ref.watch(sectorRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(adminStatusProvider),
  ),
);
final readCurrentMemberProvider = Provider(
  (ref) => ReadCurrentMember(ref.watch(identityProvider)),
);
final acceptMemberProvider = Provider(
  (ref) => AcceptMember(
    ref.watch(sectorRepositoryProvider),
    ref.watch(clockProvider),
    ref.watch(identityProvider),
    ref.watch(adminStatusProvider),
  ),
);
final refuseMemberProvider = Provider(
  (ref) => RefuseMember(
    ref.watch(sectorRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(adminStatusProvider),
  ),
);
final removeMemberProvider = Provider(
  (ref) => RemoveMember(
    ref.watch(sectorRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(adminStatusProvider),
  ),
);
final leaveSectorProvider = Provider(
  (ref) => LeaveSector(
    ref.watch(sectorRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(mySectorsStoreProvider),
  ),
);
final regenerateJoinCodeProvider = Provider(
  (ref) => RegenerateJoinCode(
    ref.watch(sectorRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(adminStatusProvider),
    ref.watch(randomProvider),
  ),
);
final deleteSectorProvider = Provider(
  (ref) => DeleteSector(
    ref.watch(sectorRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(adminStatusProvider),
    ref.watch(mySectorsStoreProvider),
  ),
);
final joinAsAdminProvider = Provider(
  (ref) => JoinAsAdmin(
    ref.watch(sectorRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(adminStatusProvider),
    ref.watch(clockProvider),
    ref.watch(phoneSettingsProvider),
    ref.watch(mySectorsStoreProvider),
  ),
);
final forgetVisitedSectorProvider = Provider(
  (ref) => ForgetVisitedSector(ref.watch(mySectorsStoreProvider)),
);
final observeAdminStatusProvider = Provider(
  (ref) => ObserveAdminStatus(ref.watch(adminStatusProvider)),
);
final isMemberAdminProvider = Provider(
  (ref) => IsMemberAdmin(ref.watch(adminStatusProvider)),
);
final listAllSectorsProvider = Provider(
  (ref) => ListAllSectors(
    ref.watch(sectorDirectoryProvider),
    ref.watch(memberAccountProvider),
  ),
);
final openAsAdminProvider = Provider(
  (ref) => OpenAsAdmin(ref.watch(mySectorsStoreProvider)),
);
final countStreetsToMoveProvider = Provider(
  (ref) => CountStreetsToMove(
    ref.watch(phoneStreetRepositoryProvider),
    ref.watch(movedStreetsLogProvider),
    ref.watch(sectorRepositoryProvider),
    ref.watch(identityProvider),
  ),
);
final moveStreetsIntoSectorProvider = Provider(
  (ref) => MoveStreetsIntoSector(
    ref.watch(phoneStreetRepositoryProvider),
    ref.watch(streetRepositoryProvider),
    ref.watch(identityProvider),
    ref.watch(movedStreetsLogProvider),
  ),
);
final chooseStartPointProvider = Provider(
  (ref) => ChooseStartPoint(
    ref.watch(mySectorsStoreProvider),
    ref.watch(phoneStreetRepositoryProvider),
  ),
);
final listRescueCentresProvider = Provider(
  (ref) => ListRescueCentres(ref.watch(sectorDirectoryProvider)),
);
final checkSectorTakenProvider = Provider(
  (ref) => CheckSectorTaken(ref.watch(sectorDirectoryProvider)),
);
final createSectorProvider = Provider(
  (ref) => CreateSector(
    ref.watch(sectorRepositoryProvider),
    ref.watch(memberAccountProvider),
    ref.watch(mySectorsStoreProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
    ref.watch(randomProvider),
  ),
);
final previewJoinProvider = Provider(
  (ref) => PreviewJoin(ref.watch(sectorDirectoryProvider)),
);
final requestToJoinProvider = Provider(
  (ref) => RequestToJoin(
    ref.watch(sectorDirectoryProvider),
    ref.watch(memberAccountProvider),
    ref.watch(mySectorsStoreProvider),
    ref.watch(clockProvider),
  ),
);
final cancelJoinRequestProvider = Provider(
  (ref) => CancelJoinRequest(
    ref.watch(sectorDirectoryProvider),
    ref.watch(memberAccountProvider),
    ref.watch(mySectorsStoreProvider),
  ),
);

// Offline download (PLAN §7), run by the app unseen.

final downloadSectorProvider = Provider(
  (ref) => DownloadSector(
    ref.watch(streetsDownloadProvider),
    ref.watch(offlineMapStoreProvider),
    ref.watch(sectorDownloadsProvider),
    ref.watch(clockProvider),
  ),
);
final refreshOfflineMapsProvider = Provider(
  (ref) => RefreshOfflineMaps(
    ref.watch(offlineMapStoreProvider),
    ref.watch(sectorDownloadsProvider),
  ),
);
final readSectorDownloadsProvider = Provider(
  (ref) => ReadSectorDownloads(ref.watch(sectorDownloadsProvider)),
);
final observeSectorDownloadsProvider = Provider(
  (ref) => ObserveSectorDownloads(ref.watch(sectorDownloadsProvider)),
);
final deleteSectorDownloadProvider = Provider(
  (ref) => DeleteSectorDownload(
    ref.watch(offlineMapStoreProvider),
    ref.watch(sectorDownloadsProvider),
  ),
);
final pruneSectorDownloadsProvider = Provider(
  (ref) => PruneSectorDownloads(
    ref.watch(mySectorsStoreProvider),
    ref.watch(deleteSectorDownloadProvider),
    ref.watch(offlineMapStoreProvider),
    ref.watch(sectorDownloadsProvider),
  ),
);
