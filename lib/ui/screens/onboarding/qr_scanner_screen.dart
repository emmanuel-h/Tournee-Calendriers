import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Scanner le QR code » (PLAN §5.2): the camera, full screen, until it
/// reads a QR code; the screen then closes with the text read
/// (`Navigator.pop`), which « Rejoindre » judges. Back closes it with
/// nothing.
///
/// `mobile_scanner` asks for the camera permission when the camera starts,
/// that is when this screen opens: never at launch. Refused or missing, the
/// screen says so; the code can still be typed.
final class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

/// A `State`: it owns the camera's controller, stopped with the screen.
final class _QrScannerScreenState extends State<QrScannerScreen> {
  final _camera = MobileScannerController(formats: [BarcodeFormat.qrCode]);

  /// The screen closes once, on the first code read.
  var _read = false;

  @override
  void dispose() {
    // Frees the camera; `dispose` returns a Future the screen need not
    // wait for.
    _camera.dispose().ignore();
    super.dispose();
  }

  void _detected(BarcodeCapture capture) {
    if (_read) return;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue case final text?) {
        _read = true;
        Navigator.of(context).pop(text);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinScan), titleSpacing: 4),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _detected,
            errorBuilder: (context, _) => ColoredBox(
              color: colors.ground,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.scannerUnavailable,
                    key: const Key('scanner.unavailable'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: colors.ink),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.snackBar,
                  borderRadius: BorderRadius.circular(AppSizes.sheetRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    l10n.scannerHint,
                    style: AppTextStyles.body.copyWith(
                      color: colors.onSnackBar,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
