import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The dark « OK » pill of a top bar that leaves an editing screen
/// (« Modifier la rue », « Modifier les portes »). Its tap target still
/// grows to [AppSizes.minTapTarget].
final class OkButton extends StatelessWidget {
  const OkButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.ink,
        foregroundColor: colors.surface,
        minimumSize: const Size(0, AppSizes.okButtonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.okButtonPadding,
        ),
        textStyle: AppTextStyles.compactButton,
      ),
      child: Text(AppLocalizations.of(context).editStreetOk),
    );
  }
}
