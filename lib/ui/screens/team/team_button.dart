import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/team/team_notifier.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// 👥 in the start screen's top bar (PLAN §5.3, Home mockup): opens Équipe.
/// A red dot on it while a join request waits, which screen readers hear
/// in its name (« Équipe, 1 demande en attente »): never colour alone.
///
/// Shown only while a tournée is open; it follows that tournée's team live.
final class TeamButton extends ConsumerWidget {
  const TeamButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    // `select`: redrawn only when the number of requests changes.
    final waiting = ref.watch(
      teamProvider.select((state) => state.waitingRequests),
    );
    final label = waiting == 0 ? l10n.homeTeam : l10n.homeTeamWaiting(waiting);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        tooltip: l10n.homeTeam,
        onPressed: () => context.push(AppRoutes.team),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.group_outlined),
            if (waiting > 0)
              Positioned(
                key: const Key('home.team.dot'),
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
