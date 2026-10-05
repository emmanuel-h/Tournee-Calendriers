import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

/// Asks before a change that loses or hides something (« Supprimer la
/// rue ? », « Modifier les étages ? »): [title], [body], [cancelLabel]
/// (« Annuler » by default) and [confirmLabel]. Returns true only when
/// [confirmLabel] was tapped; tapping beside the dialog or going back
/// counts as cancelling.
///
/// [destructive] sets [confirmLabel] apart: in the accent red, with the
/// cancel action in ink, for a removal whose marks go with it
/// (« Supprimer la porte 52 ? »). Otherwise both use the theme's colour.
///
/// [name] names the buttons for tests: `<name>.cancel`, `<name>.ok`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String name,
  required String title,
  required String body,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final cancel = cancelLabel ?? AppLocalizations.of(context).cancel;
  final colors = AppColors.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          key: ValueKey('$name.cancel'),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: colors.ink)
              : null,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancel),
        ),
        TextButton(
          key: ValueKey('$name.ok'),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: colors.accent)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
