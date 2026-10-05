import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// Asks before a change that loses or hides something (« Supprimer la
/// rue ? », « Modifier les étages ? »): [title], [body], « Annuler » and
/// [confirmLabel]. Returns true only when [confirmLabel] was tapped; tapping
/// beside the dialog or going back counts as « Annuler ».
///
/// [name] names the buttons for tests: `<name>.cancel`, `<name>.ok`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String name,
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final cancelLabel = AppLocalizations.of(context).cancel;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          key: ValueKey('$name.cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          key: ValueKey('$name.ok'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
