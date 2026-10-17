import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

/// A ⧉ that puts [text] on the phone's clipboard, then says
/// [copiedMessage] (« Code copié »). The clipboard is the phone's own: it
/// works offline.
///
/// An `IconButton` keeps a 48 dp tap target around its glyph; its
/// [tooltip] is also what screen readers say.
final class CopyButton extends StatelessWidget {
  const CopyButton({
    super.key,
    required this.text,
    required this.tooltip,
    required this.copiedMessage,
    this.color,
    this.iconSize,
  });

  final String text;
  final String tooltip;
  final String copiedMessage;

  /// The glyph's colour; ink by default.
  final Color? color;

  /// The glyph's size; the icon theme's by default.
  final double? iconSize;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    color: color ?? AppColors.of(context).ink,
    iconSize: iconSize,
    icon: const Icon(Icons.content_copy_outlined),
    onPressed: () async {
      // Taken before the `await`: the context must not be used after a
      // gap during which the screen may have gone.
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: text));
      showMessageSnackBar(messenger, message: copiedMessage);
    },
  );
}

/// The ⧉ of the phone's uid (« Identifiant de l'appareil », PLAN §5.12), on
/// Bienvenue and in Paramètres: copies the whole [id], says « Identifiant
/// copié »; TalkBack « Copier l'identifiant de l'appareil ».
final class DeviceIdCopyButton extends StatelessWidget {
  const DeviceIdCopyButton({
    super.key,
    required this.id,
    this.color,
    this.iconSize,
  });

  final String id;
  final Color? color;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CopyButton(
      text: id,
      tooltip: l10n.deviceIdCopy,
      copiedMessage: l10n.deviceIdCopied,
      color: color,
      iconSize: iconSize,
    );
  }
}
