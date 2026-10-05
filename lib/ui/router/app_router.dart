import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_notifier.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/building/adjust_doors_screen.dart';
import 'package:tournee_calendriers/ui/screens/component_gallery_screen.dart';
import 'package:tournee_calendriers/ui/screens/edit_street/edit_street_screen.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_screen.dart';
import 'package:tournee_calendriers/ui/screens/placeholder_screen.dart';
import 'package:tournee_calendriers/ui/screens/start/start_screen.dart';
import 'package:tournee_calendriers/ui/screens/street/street_screen.dart';

/// Builds the app's navigation: one route per screen of PLAN §5.
///
/// `go_router` maps a path (`/equipe`) to a screen, so any screen can be
/// opened by its path from anywhere (`context.go` replaces the stack,
/// `context.push` stacks on top). The gallery route only exists when
/// [showGallery] is true, which the app sets to `kDebugMode`.
GoRouter buildAppRouter({required bool showGallery}) => GoRouter(
  initialLocation: AppRoutes.home,
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
    _placeholder(AppRoutes.welcome, (l10n) => l10n.screenWelcome),
    _placeholder(AppRoutes.create, (l10n) => l10n.screenCreate),
    _placeholder(AppRoutes.join, (l10n) => l10n.screenJoin),
    _placeholder(AppRoutes.joinPending, (l10n) => l10n.screenJoinPending),
    _placeholder(AppRoutes.addStreets, (l10n) => l10n.screenAddStreets),
    _placeholder(AppRoutes.manualStreet, (l10n) => l10n.screenManualStreet),
    _placeholder(AppRoutes.team, (l10n) => l10n.screenTeam),
    _placeholder(AppRoutes.settings, (l10n) => l10n.screenSettings),
    _placeholder(AppRoutes.newCampaign, (l10n) => l10n.screenNewCampaign),
    _placeholder(AppRoutes.trash, (l10n) => l10n.screenTrash),
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
