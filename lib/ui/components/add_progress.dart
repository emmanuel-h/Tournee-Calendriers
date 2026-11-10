import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Ajout en cours… 2/5 » over a bar, in place of the « Ajouter N rues »
/// button while the streets are stored: both tabs of « Ajouter des rues »
/// (PLAN §5.4, §5.14). As tall as the button, so nothing moves.
final class AddProgress extends StatelessWidget {
  const AddProgress({super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppSizes.buttonHeight,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          AppLocalizations.of(context).addProgress(done, total),
          textAlign: TextAlign.center,
          style: AppTextStyles.fieldLabel,
        ),
        LinearProgressIndicator(
          value: total == 0 ? null : done / total,
          minHeight: AppSizes.progressBarHeight,
        ),
      ],
    ),
  );
}
