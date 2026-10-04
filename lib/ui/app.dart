/// Flutter widgets: screens, theme, components and the map. Widgets read view
/// states from `presentation/` and send intents back; no business logic.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_router.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_theme.dart';

/// Root widget: theme, French translations and navigation.
///
/// It is a `StatefulWidget` only to create the router once and dispose of it
/// with the app; rebuilding the root must not reset navigation.
final class TourneeApp extends StatefulWidget {
  const TourneeApp({super.key, this.showGallery = kDebugMode});

  /// Whether the debug component gallery is reachable. `kDebugMode` is a
  /// compile-time constant, false in release builds, so the gallery never
  /// ships; tests pass `false` to check that.
  final bool showGallery;

  @override
  State<TourneeApp> createState() => _TourneeAppState();
}

final class _TourneeAppState extends State<TourneeApp> {
  late final GoRouter _router = buildAppRouter(showGallery: widget.showGallery);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    // The title comes from the translations, which only exist below
    // MaterialApp: hence a callback rather than a plain `title`.
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    debugShowCheckedModeBanner: false,
    // Light only for now; the dark palette is wired in T5.1.
    theme: buildAppTheme(AppColors.light),
    locale: const Locale('fr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    routerConfig: _router,
  );
}
