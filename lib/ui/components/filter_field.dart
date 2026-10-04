import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The « Filtrer les rues… » field above a list of streets (start screen,
/// import screen). It only reports what is typed: the notifier decides what
/// matches (case and accents ignored).
///
/// Its look comes from the theme's `inputDecorationTheme`.
final class FilterField extends StatelessWidget {
  const FilterField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final hint = AppLocalizations.of(context).filterStreetsHint;
    return TextField(
      onChanged: onChanged,
      style: AppTextStyles.bodyLarge,
      // « Search » on the keyboard, and no capital forced on the first
      // letter: the filter ignores case anyway.
      textInputAction: TextInputAction.search,
      // Closing the keyboard by tapping the list is what people expect.
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      // Screen readers announce the hint as the field's name.
      decoration: InputDecoration(hintText: hint),
    );
  }
}
