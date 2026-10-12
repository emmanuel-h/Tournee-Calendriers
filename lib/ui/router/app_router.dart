import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_notifier.dart';
import 'package:tournee_calendriers/presentation/launch/launch_place.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/building/adjust_doors_screen.dart';
import 'package:tournee_calendriers/ui/screens/component_gallery_screen.dart';
import 'package:tournee_calendriers/ui/screens/corbeille/corbeille_screen.dart';
import 'package:tournee_calendriers/ui/screens/edit_street/edit_street_screen.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/create_tournee_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/join_pending_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/join_tournee_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/welcome_screen.dart';
import 'package:tournee_calendriers/ui/screens/placeholder_screen.dart';
import 'package:tournee_calendriers/ui/screens/settings/privacy_screen.dart';
import 'package:tournee_calendriers/ui/screens/settings/settings_screen.dart';
import 'package:tournee_calendriers/ui/screens/start/start_screen.dart';
import 'package:tournee_calendriers/ui/screens/street/street_screen.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';

/// Builds the app's navigation: one route per screen of PLAN §5.
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
      builder: (context, state) => StartScreen(showGallery: showGallery),
    ),
    GoRoute(
      path: AppRoutes.importStreets,
      builder: (context, state) => const ImportScreen(),
    ),
    // `/rue?id=…`; the start list passes the street's name as `extra`, so
    // the title shows before the street is read.
    GoRoute(
      path: AppRoutes.street,
      builder: (context, state) => StreetScreen(
        streetId: _streetIdOf(state),
        title: switch (state.extra) {
          final String name => name,
          _ => null,
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
      builder: (context, state) => const CreateTourneeScreen(),
    ),
    GoRoute(
      path: AppRoutes.join,
      builder: (context, state) => const JoinTourneeScreen(),
    ),
    // `/rejoindre/attente?id=…`; without a tournée, the start screen.
    GoRoute(
      path: AppRoutes.joinPending,
      redirect: (context, state) =>
          _tourneeIdOf(state) == null ? AppRoutes.home : null,
      builder: (context, state) =>
          JoinPendingScreen(tournee: _tourneeIdOf(state)!),
    ),
    _placeholder(AppRoutes.addStreets, (l10n) => l10n.screenAddStreets),
    _placeholder(AppRoutes.manualStreet, (l10n) => l10n.screenManualStreet),
    // Pushed by 👥 on the start screen; Équipe pushes the Corbeille.
    GoRoute(
      path: AppRoutes.team,
      builder: (context, state) => const TeamScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.privacy,
      builder: (context, state) => const PrivacyScreen(),
    ),
    _placeholder(AppRoutes.newCampaign, (l10n) => l10n.screenNewCampaign),
    GoRoute(
      path: AppRoutes.trash,
      builder: (context, state) => const CorbeilleScreen(),
    ),
    if (showGallery)
      GoRoute(
        path: AppRoutes.gallery,
        builder: (context, state) => const ComponentGalleryScreen(),
      ),
  ],
);

/// The street named by the link's `id`, or null when it names none.
StreetId? _streetIdOf(GoRouterState state) =>
    switch (state.uri.queryParameters['id']) {
      final String id when id.trim().isNotEmpty => StreetId(id),
      _ => null,
    };

/// The tournée named by the link's `id`, or null when it names none.
TourneeId? _tourneeIdOf(GoRouterState state) =>
    switch (state.uri.queryParameters['id']) {
      final String id when id.trim().isNotEmpty => TourneeId(id),
      _ => null,
    };

/// Where the app opens to show [place] (PLAN §4).
String launchLocation(LaunchPlace place) => switch (place) {
  LaunchOnStreets() => AppRoutes.home,
  LaunchOnWelcome() => AppRoutes.welcome,
  LaunchOnRequest(:final tournee) => AppRoutes.joinPendingOf(tournee),
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

/// A route to an empty screen whose title is picked from the translations.
GoRoute _placeholder(String path, String Function(AppLocalizations) title) =>
    GoRoute(
      path: path,
      builder: (context, state) =>
          PlaceholderScreen(title: title(AppLocalizations.of(context))),
    );
