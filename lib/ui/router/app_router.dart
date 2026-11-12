import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_notifier.dart';
import 'package:tournee_calendriers/presentation/launch/launch_place.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/add_streets_screen.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/manual_street_screen.dart';
import 'package:tournee_calendriers/ui/screens/all_sectors/all_sectors_screen.dart';
import 'package:tournee_calendriers/ui/screens/building/adjust_doors_screen.dart';
import 'package:tournee_calendriers/ui/screens/come_backs/come_backs_screen.dart';
import 'package:tournee_calendriers/ui/screens/component_gallery_screen.dart';
import 'package:tournee_calendriers/ui/screens/corbeille/corbeille_screen.dart';
import 'package:tournee_calendriers/ui/screens/edit_street/edit_street_screen.dart';
import 'package:tournee_calendriers/ui/screens/home/start_or_home.dart';
import 'package:tournee_calendriers/ui/screens/map_gallery_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/create_sector_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/join_pending_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/join_sector_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/welcome_screen.dart';
import 'package:tournee_calendriers/ui/screens/round/collecte_screen.dart';
import 'package:tournee_calendriers/ui/screens/round/dons_screen.dart';
import 'package:tournee_calendriers/ui/screens/round/round_recap_screen.dart';
import 'package:tournee_calendriers/ui/screens/settings/changelog_screen.dart';
import 'package:tournee_calendriers/ui/screens/settings/privacy_screen.dart';
import 'package:tournee_calendriers/ui/screens/settings/settings_screen.dart';
import 'package:tournee_calendriers/ui/screens/street/street_screen.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';

/// Builds the app's navigation: one route per screen of PLAN §5 built so
/// far (a screen still to build gets its route with it).
///
/// `go_router` maps a path (`/equipe`) to a screen, so any screen can be
/// opened by its path from anywhere (`context.go` replaces the stack,
/// `context.push` stacks on top). The gallery route only exists when
/// [showGallery] is true, which the app sets to `kDebugMode`.
///
/// [navigatorKey] reaches the app's navigator from outside any screen (the
/// dialog of a failed save, `SaveFailedAlert`).
GoRouter buildAppRouter({
  required bool showGallery,
  GlobalKey<NavigatorState>? navigatorKey,
  String initialLocation = AppRoutes.home,
}) => GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      // Accueil while a secteur is open, « Aucun secteur ouvert » otherwise.
      builder: (context, state) => StartOrHome(showGallery: showGallery),
    ),
    GoRoute(
      path: AppRoutes.addStreets,
      builder: (context, state) => const AddStreetsScreen(),
    ),
    GoRoute(
      path: AppRoutes.manualStreet,
      builder: (context, state) => const ManualStreetScreen(),
    ),
    // `/rue?id=…`; the start list passes the street's name as `extra`, so
    // the title shows before the street is read. `&numero=12` (and
    // `&porte=A5-51`) come from « À repasser » or a reminder: the house
    // (or the door) to show ringed.
    GoRoute(
      path: AppRoutes.street,
      builder: (context, state) => StreetScreen(
        streetId: _streetIdOf(state),
        title: switch (state.extra) {
          final String name => name,
          _ => null,
        },
        ringAt: _ringedHouseOf(state),
        ringDoor: switch (state.uri.queryParameters['porte']) {
          final String id => DwellingKey.parse(id),
          null => null,
        },
      ),
    ),
    // `/rue/modifier?id=…`, pushed by ✏ on the street screen.
    GoRoute(
      path: AppRoutes.editStreet,
      builder: (context, state) =>
          EditStreetScreen(streetId: _streetIdOf(state)),
    ),
    // `/rue/modifier/portes?id=…&numero=8`, pushed by « Modifier les
    // portes » in the « Gérer l'immeuble » menu of the grid.
    GoRoute(
      path: AppRoutes.adjustDoors,
      builder: (context, state) =>
          AdjustDoorsScreen(building: _buildingOf(state)),
    ),
    GoRoute(
      path: AppRoutes.welcome,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.create,
      builder: (context, state) => const CreateSectorScreen(),
    ),
    GoRoute(
      path: AppRoutes.join,
      builder: (context, state) => const JoinSectorScreen(),
    ),
    // `/rejoindre/attente?id=…`; without a secteur, the start screen.
    GoRoute(
      path: AppRoutes.joinPending,
      redirect: (context, state) =>
          _sectorIdOf(state) == null ? AppRoutes.home : null,
      builder: (context, state) =>
          JoinPendingScreen(sector: _sectorIdOf(state)!),
    ),
    // Pushed by Accueil's title; Secteur pushes « Ajouter des
    // rues », the Corbeille and « Collecte ».
    GoRoute(
      path: AppRoutes.team,
      builder: (context, state) => const TeamScreen(),
    ),
    // Pushed by « Tous les secteurs › » of « Mes secteurs » (admins).
    GoRoute(
      path: AppRoutes.allSectors,
      builder: (context, state) => const AllSectorsScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.privacy,
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      path: AppRoutes.changelog,
      builder: (context, state) => const ChangelogScreen(),
    ),
    GoRoute(
      path: AppRoutes.trash,
      builder: (context, state) => const CorbeilleScreen(),
    ),
    GoRoute(
      path: AppRoutes.roundDons,
      builder: (context, state) => const DonsScreen(),
    ),
    GoRoute(
      path: AppRoutes.roundRecap,
      builder: (context, state) => const RoundRecapScreen(),
    ),
    // Pushed by « À repasser » on Accueil, or a reminder of several houses.
    GoRoute(
      path: AppRoutes.comeBacks,
      builder: (context, state) => const ComeBacksScreen(),
    ),
    // Pushed by « COLLECTE 2026 » of Secteur.
    GoRoute(
      path: AppRoutes.collecte,
      builder: (context, state) => const CollecteScreen(),
    ),
    if (showGallery)
      GoRoute(
        path: AppRoutes.gallery,
        builder: (context, state) => const ComponentGalleryScreen(),
      ),
    if (showGallery)
      GoRoute(
        path: AppRoutes.galleryMap,
        builder: (context, state) => const MapGalleryScreen(),
      ),
  ],
);

/// The street named by the link's `id`, or null when it names none.
StreetId? _streetIdOf(GoRouterState state) =>
    switch (state.uri.queryParameters['id']) {
      final String id when id.trim().isNotEmpty => StreetId(id),
      _ => null,
    };

/// The secteur named by the link's `id`, or null when it names none.
SectorId? _sectorIdOf(GoRouterState state) =>
    switch (state.uri.queryParameters['id']) {
      final String id when id.trim().isNotEmpty => SectorId(id),
      _ => null,
    };

/// Where the app opens to show [place] (PLAN §4).
String launchLocation(LaunchPlace place) => switch (place) {
  LaunchOnStreets() => AppRoutes.home,
  LaunchOnWelcome() => AppRoutes.welcome,
  LaunchOnRequest(:final sector) => AppRoutes.joinPendingOf(sector),
};

/// The house of the link's `numero`, or null when it names none.
HouseNumber? _ringedHouseOf(GoRouterState state) =>
    switch (state.uri.queryParameters['numero']) {
      final String text => switch (HouseNumber.parse(text)) {
        Ok(:final value) => value,
        Err() => null,
      },
      null => null,
    };

/// The building named by the link's `id` and `numero`, or null when it
/// names none.
BuildingGridKey? _buildingOf(GoRouterState state) {
  final street = _streetIdOf(state);
  final number = switch (state.uri.queryParameters['numero']) {
    final String text => HouseNumber.parse(text),
    null => null,
  };
  return switch ((street, number)) {
    (final StreetId street, Ok(value: final number)) => (
      street: street,
      number: number,
    ),
    _ => null,
  };
}
