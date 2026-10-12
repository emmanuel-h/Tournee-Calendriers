import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

/// The ⧉ right of a tournée's join code (PLAN §5.2, §5.8): puts [code] on
/// the phone's clipboard, as shown (`K7P-2QX`), so it can be pasted in a
/// chat, then says « Code copié ». « Rejoindre » accepts it with or
/// without the dash. The clipboard is the phone's own: it works offline.
///
/// An `IconButton` keeps a 48 dp tap target around its 24 dp glyph; its
/// tooltip « Copier le code » is also what screen readers say.
final class CopyCodeButton extends StatelessWidget {
  const CopyCodeButton({super.key, required this.code});

  /// The code as shown, dash included.
  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.teamCopyCode,
      color: AppColors.of(context).ink,
      icon: const Icon(Icons.content_copy_outlined),
      onPressed: () async {
        // Taken before the `await`: the context must not be used after a
        // gap during which the screen may have gone.
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(ClipboardData(text: code));
        showMessageSnackBar(messenger, message: l10n.teamCodeCopied);
      },
    );
  }
}
