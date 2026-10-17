/// Flutter widgets: screens, theme, components and the map. Widgets read view
/// states from `presentation/` and send intents back; no business logic.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_loss.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_purge.dart';
import 'package:tournee_calendriers/presentation/launch/launch_place.dart';
import 'package:tournee_calendriers/presentation/my_tournees/tournee_loss_notice.dart';
import 'package:tournee_calendriers/presentation/my_tournees/tournee_loss_notifier.dart';
import 'package:tournee_calendriers/presentation/settings/settings_notifier.dart';
import 'package:tournee_calendriers/presentation/settings/settings_state.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_router.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_theme.dart';

/// Root widget: theme, French translations and navigation. It opens where
/// `launchPlaceProvider` says (« Bienvenue », « Demande envoyée » or the
/// start screen, PLAN §4), showing the bare ground for the moment the phone
/// takes to tell.
///
/// It also tells, over whatever screen is shown, that the member lost one
/// of their tournées (`tourneeLossProvider`, PLAN §5.3): the open one
/// lost, it goes back to the start screen, with none open.
///
/// It is a `StatefulWidget` only to create the router once and dispose of it
/// with the app; rebuilding the root (a new theme) must not reset
/// navigation. A `ConsumerStatefulWidget` is the same with access to
/// providers (`ref`).
final class TourneeApp extends ConsumerStatefulWidget {
  const TourneeApp({
    super.key,
    this.showGallery = kDebugMode,
    this.navigatorKey,
  });

  /// Whether the debug component gallery is reachable. `kDebugMode` is a
  /// compile-time constant, false in release builds, so the gallery never
  /// ships; tests pass `false` to check that.
  final bool showGallery;

  /// The key of the app's navigator, so a dialog can be shown from outside
  /// any screen (`SaveFailedAlert`).
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  ConsumerState<TourneeApp> createState() => _TourneeAppState();
}

final class _TourneeAppState extends ConsumerState<TourneeApp> {
  /// Made once, as soon as the app knows where it opens.
  GoRouter? _router;

  /// The app's `ScaffoldMessenger`, which shows a message above every
  /// screen and keeps it on screen when the app goes to another one.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  GoRouter _routerFrom(String location) => buildAppRouter(
    showGallery: widget.showGallery,
    navigatorKey: widget.navigatorKey,
    initialLocation: location,
  );

  /// « Vous avez été retiré de la tournée 49. », « La tournée 49 a été
  /// supprimée. » or « Vous n'êtes plus administrateur… » (a tournée only
  /// visited, PLAN §5.12), as « Demande refusée » is told: a message over the next
  /// screen. Nothing is shown before the app has its first screen.
  void _tell(TourneeLossNotice notice) {
    final messenger = _messengerKey.currentState;
    final router = _router;
    if (messenger == null || router == null) return;
    final l10n = AppLocalizations.of(messenger.context);
    showMessageSnackBar(
      messenger,
      message: switch (notice.loss) {
        TourneeLoss.removed => l10n.tourneeRemoved('${notice.number}'),
        TourneeLoss.deleted => l10n.tourneeDeleted('${notice.number}'),
        TourneeLoss.adminRevoked => l10n.tourneeAdminRevoked(
          '${notice.number}',
        ),
      },
    );
    // Its screens (Équipe, its streets) show a tournée the phone forgot.
    if (notice.wasOpen) router.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    // The 30-day purge of the Corbeille, on the streets bound now and on
    // those of each tournée opened later (PLAN §5.11). `ref.listen` starts
    // it and keeps it alive without redrawing the app when it ends; there
    // is nothing to show of it.
    ref.listen(corbeillePurgeProvider, (_, _) {});
    // `ref.listen` runs the function at each new notice, without redrawing
    // the app; listening also starts following the member's tournées.
    ref.listen(tourneeLossProvider, (_, notice) {
      if (notice != null) _tell(notice);
    });
    // `select`: the app redraws when the theme changes, not when the name
    // does.
    final theme = ref.watch(settingsProvider.select((state) => state.theme));
    // Where the app opens: decided once, from the phone alone (PLAN §4).
    // `??=` keeps the first router; later answers change nothing.
    final router = _router ??= switch (ref.watch(launchPlaceProvider)) {
      AsyncData(:final value) => _routerFrom(launchLocation(value)),
      // The phone's storage could not be read: its start screen says so.
      AsyncError() => _routerFrom(AppRoutes.home),
      // A moment while the phone's streets are read.
      AsyncLoading() => null,
    };
    final themeMode = switch (theme) {
      AppTheme.system => ThemeMode.system,
      AppTheme.light => ThemeMode.light,
      AppTheme.dark => ThemeMode.dark,
    };
    if (router == null) {
      // The app's ground, nothing else, until it knows where to open.
      return MaterialApp(
        key: const ValueKey('launching'),
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(AppColors.light),
        darkTheme: buildAppTheme(AppColors.dark),
        themeMode: themeMode,
        home: const Scaffold(),
      );
    }
    return MaterialApp.router(
      key: const ValueKey('app'),
      // The title comes from the translations, which only exist below
      // MaterialApp: hence a callback rather than a plain `title`.
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(AppColors.light),
      // The first proposal of the dark palette; T5.1 reviews it on a phone.
      darkTheme: buildAppTheme(AppColors.dark),
      // Paramètres → Thème; « Système » follows the phone.
      themeMode: themeMode,
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      scaffoldMessengerKey: _messengerKey,
    );
  }
}
