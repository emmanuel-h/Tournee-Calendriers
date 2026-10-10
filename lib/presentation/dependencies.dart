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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/street_view_preferences.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/application/use_cases/find_imported_streets.dart';
import 'package:tournee_calendriers/application/use_cases/hide_done.dart';
import 'package:tournee_calendriers/application/use_cases/import_reference_area.dart';
import 'package:tournee_calendriers/application/use_cases/list_commune_streets.dart';
import 'package:tournee_calendriers/application/use_cases/mark_dwelling.dart';
import 'package:tournee_calendriers/application/use_cases/mark_house.dart';
import 'package:tournee_calendriers/application/use_cases/observe_street.dart';
import 'package:tournee_calendriers/application/use_cases/observe_streets.dart';
import 'package:tournee_calendriers/application/use_cases/search_communes.dart';
import 'package:tournee_calendriers/application/use_cases/set_house_details.dart';
import 'package:tournee_calendriers/application/use_cases/sign_in.dart';
import 'package:tournee_calendriers/application/use_cases/undo_last_change.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

// Ports, bound by bootstrap/.

final streetRepositoryProvider = Provider<StreetRepository>(
  (ref) => _unbound('StreetRepository'),
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
