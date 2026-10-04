import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// Shows a short message with one action at the bottom of the screen, like
/// « 7 → Personne [Annuler] » after marking a house (PLAN §5.6).
///
/// Colours and shape come from the theme's `snackBarTheme`. A new message
/// replaces the one on screen instead of queuing behind it: after several
/// quick taps, only the last change can be undone.
void showActionSnackBar(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        // Keep the action-less timeout even when an action is present
        // (Material 3 otherwise keeps snackbars with an action until tapped).
        persist: false,
        margin: const EdgeInsets.fromLTRB(
          AppSizes.gutter,
          0,
          AppSizes.gutter,
          20,
        ),
        action: SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}
