import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/team/team_notifier.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// The Secteur button in Accueil's top bar (PLAN §5.14, RunStart mockup), a
/// folded map: opens Secteur, where the secteur is prepared (members,
/// streets, communes). A red dot on it while a join request waits, which
/// screen readers hear in its name (« Secteur, 1 demande en attente »):
/// never colour alone.
///
/// Shown only while a secteur is open; it follows that secteur's team live.
final class SectorButton extends ConsumerWidget {
  const SectorButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    // `select`: redrawn only when the number of requests changes.
    final waiting = ref.watch(
      teamProvider.select((state) => state.waitingRequests),
    );
    final label = waiting == 0
        ? l10n.homeSector
        : l10n.homeSectorWaiting(waiting);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        tooltip: l10n.homeSector,
        onPressed: () => context.push(AppRoutes.team),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.map_outlined),
            if (waiting > 0)
              Positioned(
                key: const Key('home.sectorButton.dot'),
                top: -2,
                right: -2,
                child: Container(
                  width: AppSizes.waitingDot,
                  height: AppSizes.waitingDot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent,
                    // A ring of the ground, so the dot stands off the icon.
                    border: Border.all(color: colors.ground, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
