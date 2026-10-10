import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The open tournée as the title of the screen (« Tournée 49 · 2026 ▾ »
/// over « CS Villefranche », PLAN §5.3, Home mockup): a button that opens
/// « Mes tournées ».
final class TourneeTitleButton extends StatelessWidget {
  const TourneeTitleButton({
    super.key,
    required this.tournee,
    required this.onPressed,
  });

  final TourneeSummary tournee;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final title = tourneeTitle(l10n, tournee);
    // One button for screen readers, named as the mockup does: « Tournée
    // 49 · 2026, CS Villefranche. Changer de tournée ».
    return Semantics(
      button: true,
      label: l10n.tourneeTitleSemantics(title, tournee.centre.name),
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSizes.tileRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      key: const Key('home.tournee'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.tourneeTitle.copyWith(
                        color: colors.ink,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: AppSizes.titleChevron,
                    color: colors.ink,
                  ),
                ],
              ),
              Text(
                tournee.centre.name,
                key: const Key('home.centre'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.small.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Tournée 49 · 2026 »: how a tournée is named everywhere but on the
/// join screens (PLAN §5.2).
String tourneeTitle(AppLocalizations l10n, TourneeSummary tournee) =>
    l10n.tourneeTitle('${tournee.number.value}', '${tournee.campaign.value}');
