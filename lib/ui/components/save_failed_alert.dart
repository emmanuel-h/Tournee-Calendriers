import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// Tells the user that a change could not be kept on the phone (its storage
/// is full), with a dialog over whatever screen is open.
///
/// The phone storage keeps each change in memory first and writes it out
/// afterwards, so the screen already shows the change when the write fails:
/// without this dialog the user would never know it is gone at the next
/// start. The storage writes the whole street, so the change is kept as
/// soon as a later write of that street succeeds.
///
/// It needs no `BuildContext` of its own: the failure comes from no screen
/// in particular (the composition root catches it), so it reaches the
/// app's navigator through [navigatorKey], the key given to the router.
final class SaveFailedAlert {
  SaveFailedAlert(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  /// Whether the dialog is on screen: several failures in a row (a tap,
  /// then the next) show it once.
  var _showing = false;

  /// Shows the dialog, unless it is on screen already or no screen is up
  /// yet.
  void show() {
    final context = navigatorKey.currentContext;
    if (_showing || context == null) return;
    _showing = true;
    final l10n = AppLocalizations.of(context);
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.saveFailedTitle),
          content: Text(l10n.saveFailedBody),
          actions: [
            TextButton(
              key: const ValueKey('saveFailed.ok'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.saveFailedOk),
            ),
          ],
        ),
      ).whenComplete(() => _showing = false),
    );
  }
}
