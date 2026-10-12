import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// A field's label above it (« Centre de secours », « Code »).
final class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTextStyles.fieldLabel.copyWith(color: AppColors.of(context).ink),
  );
}

/// What is wrong with a field, under it, in red; read out as soon as it
/// shows.
final class FieldProblem extends StatelessWidget {
  const FieldProblem(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      text,
      style: AppTextStyles.small.copyWith(
        color: AppColors.of(context).accent,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// A message about the whole screen (« Aucune tournée n'a ce code. »),
/// read out as soon as it shows, with an action beside it when one helps
/// (« Réessayer »).
final class ScreenMessage extends StatelessWidget {
  const ScreenMessage(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Semantics(
      liveRegion: true,
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(
                color: AppColors.of(context).ink,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// The tournée to confirm or waited for, as the join mockup draws it: its
/// number in a red square, « Tournée 49 · CS Villefranche » over
/// « Campagne 2026 ».
final class TourneePreviewCard extends StatelessWidget {
  const TourneePreviewCard({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final int number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(AppSizes.previewCardRadius),
        ),
        child: Row(
          spacing: 14,
          children: [
            // The number is in the title too: the square is decoration.
            ExcludeSemantics(
              child: Container(
                width: AppSizes.previewBadge,
                height: AppSizes.previewBadge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(
                    AppSizes.previewBadgeRadius,
                  ),
                ),
                child: Text(
                  '$number',
                  style: AppTextStyles.previewBadge.copyWith(
                    color: colors.onAccent,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.previewTitle.copyWith(
                      color: colors.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.small.copyWith(color: colors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
