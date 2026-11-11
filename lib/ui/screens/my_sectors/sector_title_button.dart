import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/presentation/team/team_notifier.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The open secteur as the title of Accueil (« Secteur 49 · 2026 ▾ » over
/// « CS Villefranche », PLAN §5.3, §5.14, Home mockup): a button that opens
/// Secteur, where the secteur is prepared and from which « Changer de
/// secteur » opens « Mes secteurs » (#135).
///
/// A red dot after ▾ while a join request waits, which screen readers hear
/// in its name (« Secteur 49 · 2026, CS Villefranche, 1 demande en
/// attente »): never colour alone. It follows the open secteur's team live.
final class SectorTitleButton extends ConsumerWidget {
  const SectorTitleButton({
    super.key,
    required this.sector,
    required this.onPressed,
  });

  final SectorSummary sector;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final title = sectorTitle(l10n, sector);
    // `select`: redrawn only when the number of requests changes, not on
    // every change of the team.
    final waiting = ref.watch(
      teamProvider.select((state) => state.waitingRequests),
    );
    // One button for screen readers: the title, the centre and the
    // requests in one name.
    return Semantics(
      button: true,
      label: l10n.sectorTitleSemantics(waiting, title, sector.centre.name),
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
                  if (waiting > 0)
                    Container(
                      key: const Key('home.sector.dot'),
                      width: AppSizes.waitingDot,
                      height: AppSizes.waitingDot,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accent,
                      ),
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

/// The app's name as the title of the start screen while no secteur is
/// open (« Tournée des calendriers ▾ »): a button that opens « Mes
/// secteurs » too, so a phone with streets of its own reaches « Créer » and
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

/// « Secteur 49 · 2026 »: how a secteur is named everywhere but on the
/// join screens (PLAN §5.2).
String sectorTitle(AppLocalizations l10n, SectorSummary sector) =>
    l10n.sectorTitle('${sector.number.value}', '${sector.campaign.value}');
