import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/map/phone_location.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// The round « Me localiser » button over the map (Home mockup, PLAN
/// §5.3): a tap finds the phone through [phone] and hands the position to
/// [onLocated]; when it cannot, a message says why.
///
/// Nothing touches the location before the first tap: the permission
/// dialog shows then, never at launch.
final class LocateMeButton extends StatefulWidget {
  const LocateMeButton({
    super.key,
    required this.phone,
    required this.onLocated,
  });

  final PhoneLocation phone;
  final ValueChanged<GeoPoint> onLocated;

  @override
  State<LocateMeButton> createState() => _LocateMeButtonState();
}

final class _LocateMeButtonState extends State<LocateMeButton> {
  /// True while a position is being looked for: a second tap then does
  /// nothing, and a spinner replaces the icon (a GPS fix may take seconds).
  var _locating = false;

  Future<void> _locate() async {
    setState(() => _locating = true);
    final outcome = await locateMe(widget.phone);
    // The map may have closed while the GPS answered: `mounted` is false
    // once the widget has left the screen, and its context is no use then.
    if (!mounted) return;
    setState(() => _locating = false);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    switch (outcome) {
      case Located(:final position):
        widget.onLocated(position);
      case LocationServiceOff():
        showMessageSnackBar(messenger, message: l10n.mapLocationServiceOff);
      case LocationRefused():
        showMessageSnackBar(messenger, message: l10n.mapLocationRefused);
      case LocationRefusedForever():
        showActionSnackBar(
          messenger,
          message: l10n.mapLocationRefusedForever,
          actionLabel: l10n.mapLocationSettings,
          onAction: widget.phone.openSettings,
        );
      case PositionUnavailable():
        showMessageSnackBar(messenger, message: l10n.mapPositionUnavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = AppLocalizations.of(context).mapLocateMe;
    return Tooltip(
      message: label,
      // The tooltip already names the button for screen readers.
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: colors.surface,
          shape: CircleBorder(side: BorderSide(color: colors.divider)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('map.locateMe'),
            onTap: _locating ? null : _locate,
            child: SizedBox.square(
              dimension: AppSizes.mapButton,
              child: Center(
                child: _locating
                    ? SizedBox.square(
                        dimension: AppSizes.mapButtonIcon,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.ink,
                        ),
                      )
                    : Icon(
                        Icons.gps_not_fixed,
                        size: AppSizes.mapButtonIcon,
                        color: colors.ink,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
