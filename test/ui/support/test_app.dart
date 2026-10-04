import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_theme.dart';

/// Wraps [child] in what every widget of the app expects above it: the app
/// theme, the French translations and a `Scaffold` (for snackbars).
Widget testApp(Widget child) => MaterialApp(
  theme: buildAppTheme(AppColors.light),
  locale: const Locale('fr'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);
