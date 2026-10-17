import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/components/copy_button.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// The ⧉ right of a tournée's join code (PLAN §5.2, §5.8): puts [code] on
/// the phone's clipboard, as shown (`K7P-2QX`), so it can be pasted in a
/// chat, then says « Code copié ». « Rejoindre » accepts it with or
/// without the dash. TalkBack says « Copier le code ».
final class CopyCodeButton extends StatelessWidget {
  const CopyCodeButton({super.key, required this.code});

  /// The code as shown, dash included.
  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CopyButton(
      text: code,
      tooltip: l10n.teamCopyCode,
      copiedMessage: l10n.teamCodeCopied,
    );
  }
}
