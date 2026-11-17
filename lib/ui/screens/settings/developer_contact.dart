import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// The developer's address: the contact of `PRIVACY.md`, where members
/// write from « Écrire au développeur » (PLAN §5.9, #118).
const developerEmail = 'mandarinetech.dev@gmail.com';

/// The `mailto:` link of a new message to [developerEmail] with [subject]
/// and no body.
///
/// The query is written by hand: `Uri(queryParameters: …)` turns spaces
/// into « + », which mail apps show as they are. `encodeComponent` writes
/// them « %20 », as a `mailto:` link expects.
Uri developerMailUri(String subject) => Uri(
  scheme: 'mailto',
  path: developerEmail,
  query: 'subject=${Uri.encodeComponent(subject)}',
);

/// Opens the phone's mail app on a new message to the developer, its
/// subject « Tournée Calendriers [version] : idée ». Nothing else goes into
/// it: no secteur, street or place (location privacy). The app sends
/// nothing itself; the mail app may keep the message until the network is
/// back.
///
/// When no mail app opens, a snackbar gives the address with « Copier ».
/// `launchUrl` answers false when nothing can open the link, and may throw a
/// `PlatformException` when the plugin fails: both end in the snackbar.
Future<void> writeToDeveloper(
  BuildContext context, {
  required String version,
}) async {
  final l10n = AppLocalizations.of(context);
  // Taken before the `await`: the context must not be used after a gap
  // during which the screen may have gone.
  final messenger = ScaffoldMessenger.of(context);
  bool opened;
  try {
    opened = await launchUrl(
      developerMailUri(l10n.contactSubject(version)),
      mode: LaunchMode.externalApplication,
    );
  } on PlatformException {
    opened = false;
  }
  if (opened) return;
  showActionSnackBar(
    messenger,
    message: l10n.contactFailed(developerEmail),
    actionLabel: l10n.contactCopy,
    onAction: () =>
        Clipboard.setData(const ClipboardData(text: developerEmail)),
  );
}
