import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/component_gallery_screen.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_screen.dart';
import 'package:tournee_calendriers/ui/screens/placeholder_screen.dart';
import 'package:tournee_calendriers/ui/screens/start/start_screen.dart';

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
    // Until the street screen exists (#11), a placeholder titled with the
    // street's name, which the start list passes as `extra`.
    GoRoute(
      path: AppRoutes.street,
      builder: (context, state) => PlaceholderScreen(
        title: switch (state.extra) {
          final String name => name,
          _ => AppLocalizations.of(context).screenStreet,
        },
      ),
    ),
    _placeholder(AppRoutes.welcome, (l10n) => l10n.screenWelcome),
    _placeholder(AppRoutes.create, (l10n) => l10n.screenCreate),
    _placeholder(AppRoutes.join, (l10n) => l10n.screenJoin),
    _placeholder(AppRoutes.joinPending, (l10n) => l10n.screenJoinPending),
    _placeholder(AppRoutes.addStreets, (l10n) => l10n.screenAddStreets),
    _placeholder(AppRoutes.manualStreet, (l10n) => l10n.screenManualStreet),
    _placeholder(AppRoutes.editStreet, (l10n) => l10n.screenEditStreet),
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

/// A route to an empty screen whose title is picked from the translations.
GoRoute _placeholder(String path, String Function(AppLocalizations) title) =>
    GoRoute(
      path: path,
      builder: (context, state) =>
          PlaceholderScreen(title: title(AppLocalizations.of(context))),
    );
