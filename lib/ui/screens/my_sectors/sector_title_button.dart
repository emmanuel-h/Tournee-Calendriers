import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The open tournée as the title of the screen (« Tournée 49 · 2026 ▾ »
/// over « CS Villefranche », PLAN §5.3, Home mockup): a button that opens
/// « Mes secteurs ».
final class SectorTitleButton extends StatelessWidget {
  const SectorTitleButton({
    super.key,
    required this.sector,
    required this.onPressed,
  });

  final SectorSummary sector;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final title = sectorTitle(l10n, sector);
    // One button for screen readers, named as the mockup does: « Tournée
    // 49 · 2026, CS Villefranche. Changer de tournée ».
    return Semantics(
      button: true,
      label: l10n.sectorTitleSemantics(title, sector.centre.name),
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
                      key: const Key('home.sector'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.sectorTitle.copyWith(
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
                sector.centre.name,
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

/// The app's name as the title of the start screen while no tournée is
/// open (« Tournée des calendriers ▾ »): a button that opens « Mes
/// tournées » too, so a phone with streets of its own reaches « Créer » and
/// « Rejoindre » from there.
final class AppTitleButton extends StatelessWidget {
  const AppTitleButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: l10n.appTitleSemantics(l10n.appTitle),
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSizes.tileRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Flexible(
                child: Text(
                  l10n.appTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: AppSizes.titleChevron,
                color: colors.ink,
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
String sectorTitle(AppLocalizations l10n, SectorSummary sector) =>
    l10n.sectorTitle('${sector.number.value}', '${sector.campaign.value}');
