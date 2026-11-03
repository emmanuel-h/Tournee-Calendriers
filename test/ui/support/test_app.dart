import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_theme.dart';

/// Wraps [child] in what every widget of the app expects above it: the app
/// theme ([colors], light by default), the French translations and a
/// `Scaffold` (for snackbars).
Widget testApp(Widget child, {AppColors colors = AppColors.light}) =>
    MaterialApp(
      theme: buildAppTheme(colors),
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    );
