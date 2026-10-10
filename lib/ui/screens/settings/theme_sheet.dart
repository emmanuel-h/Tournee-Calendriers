import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/settings/settings_notifier.dart';
import 'package:tournee_calendriers/presentation/settings/settings_state.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// Opens the theme choice (Paramètres → Thème, PLAN §5.9).
Future<void> showThemeSheet(BuildContext context) => showAppBottomSheet<void>(
  context: context,
  builder: (_) => const ThemeSheet(),
);

/// « Système | Clair | Sombre »: a tap redraws the app in that theme and
/// closes the sheet.
final class ThemeSheet extends ConsumerWidget {
  const ThemeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = ref.watch(settingsProvider.select((state) => state.theme));
    return SheetScaffold(
      title: l10n.settingsTheme,
      children: [
        SegmentedChoice<AppTheme>(
          groupLabel: l10n.settingsTheme,
          segments: [
            for (final choice in AppTheme.values)
              Segment(
                value: choice,
                label: themeName(l10n, choice),
                key: ValueKey('theme.${choice.name}'),
              ),
          ],
          selected: theme,
          onSelected: (choice) {
            unawaited(ref.read(settingsProvider.notifier).chooseTheme(choice));
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

/// The French name of [theme] (« Système », « Clair », « Sombre »).
String themeName(AppLocalizations l10n, AppTheme theme) => switch (theme) {
  AppTheme.system => l10n.themeSystem,
  AppTheme.light => l10n.themeLight,
  AppTheme.dark => l10n.themeDark,
};
