import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

/// A tournée's join code as a QR code (PLAN §5.2): Équipe and « Nouvelle
/// tournée » show it for a newcomer to scan.
///
/// [data] is what the QR code holds, the code alone (`K7P2QX`); [code] is
/// the code as shown (`K7P-2QX`), which screen readers say instead of the
/// picture.
final class JoinQrCode extends StatelessWidget {
  const JoinQrCode({
    super.key,
    required this.data,
    required this.code,
    required this.size,
  });

  final String data;
  final String code;

  /// The side of the square, quiet zone included.
  final double size;

  @override
  Widget build(BuildContext context) {
    // A QR code scans best dark on light: it keeps the light palette's ink
    // and white in the dark theme too.
    const qrInk = AppColors.light;
    return Semantics(
      // A node of its own, not merged with the code beside it.
      container: true,
      label: AppLocalizations.of(context).teamQrSemantics(code),
      image: true,
      excludeSemantics: true,
      child: ColoredBox(
        color: qrInk.surface,
        child: QrImageView(
          data: data,
          size: size,
          padding: const EdgeInsets.all(4),
          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: qrInk.ink),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: qrInk.ink,
          ),
        ),
      ),
    );
  }
}

/// « Partager »: the phone's share sheet with « Tournée 49 · CS
/// Villefranche » and the [code] to join it.
void shareJoinCode(
  AppLocalizations l10n, {
  required int number,
  required String centre,
  required String code,
}) => unawaited(
  SharePlus.instance.share(
    ShareParams(text: l10n.teamShareText('$number', centre, code)),
  ),
);
