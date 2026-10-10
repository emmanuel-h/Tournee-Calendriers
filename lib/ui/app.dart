/// Flutter widgets: screens, theme, components and the map. Widgets read view
/// states from `presentation/` and send intents back; no business logic.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/settings/settings_notifier.dart';
import 'package:tournee_calendriers/presentation/settings/settings_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_router.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_theme.dart';

/// Root widget: theme, French translations and navigation.
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
  late final GoRouter _router = buildAppRouter(
    showGallery: widget.showGallery,
    navigatorKey: widget.navigatorKey,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `select`: the app redraws when the theme changes, not when the name
    // does.
    final theme = ref.watch(settingsProvider.select((state) => state.theme));
    return MaterialApp.router(
      // The title comes from the translations, which only exist below
      // MaterialApp: hence a callback rather than a plain `title`.
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(AppColors.light),
      // The first proposal of the dark palette; T5.1 reviews it on a phone.
      darkTheme: buildAppTheme(AppColors.dark),
      // Paramètres → Thème; « Système » follows the phone.
      themeMode: switch (theme) {
        AppTheme.system => ThemeMode.system,
        AppTheme.light => ThemeMode.light,
        AppTheme.dark => ThemeMode.dark,
      },
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: _router,
    );
  }
}
