import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';
import 'package:tournee_calendriers/presentation/team/team_notifier.dart';
import 'package:tournee_calendriers/presentation/team/team_state.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/my_tournees/my_tournees_sheet.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The banner under the title of Accueil while an admin visits the open
/// tournée without being in its team (PLAN §5.12, HomeAdmin mockup): a
/// shield, « Administrateur · pas membre » over « Vous n'êtes pas dans
/// l'équipe de cette tournée. », and « Rejoindre », which makes them a
/// member at once. In the « repasser » blue. Nothing for anyone else.
final class AdminVisitBanner extends ConsumerWidget {
  const AdminVisitBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visiting = ref.watch(
      currentTourneeProvider.select((tournee) => tournee?.isVisiting ?? false),
    );
    if (!visiting) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = AppTextStyles.small.copyWith(color: colors.onComeBack);
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSizes.gutter, 8, AppSizes.gutter, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: colors.comeBack,
        border: Border.all(
          color: colors.onComeBack,
          width: AppSizes.borderWidth,
        ),
        borderRadius: BorderRadius.circular(AppSizes.adminBannerRadius),
      ),
      child: Row(
        spacing: 10,
        children: [
          // Decoration: the words say it.
          ExcludeSemantics(
            child: Icon(
              Icons.shield_outlined,
              size: AppSizes.adminBannerIcon,
              color: colors.onComeBack,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  l10n.adminBannerTitle,
                  key: const Key('home.adminBanner'),
                  style: text.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(l10n.adminBannerBody, style: text),
              ],
            ),
          ),
          FilledButton(
            key: const Key('home.adminJoin'),
            onPressed: () => unawaited(_join(context, ref)),
            style: FilledButton.styleFrom(
              backgroundColor: colors.onComeBack,
              foregroundColor: colors.comeBack,
              minimumSize: const Size(0, AppSizes.minTapTarget),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: AppTextStyles.pill,
            ),
            child: Text(l10n.adminBannerJoin),
          ),
        ],
      ),
    );
  }

  /// Joins once the phone has a first name for the team; tells why when it
  /// could not (offline).
  Future<void> _join(BuildContext context, WidgetRef ref) async {
    if (!await ensureMemberName(context) || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final failure = await ref.read(teamProvider.notifier).joinAsAdmin();
    if (failure == null) return;
    showMessageSnackBar(
      messenger,
      message: switch (failure) {
        TeamActionFailure.offline => l10n.teamOffline,
        TeamActionFailure.teamChanged => l10n.teamChanged,
        TeamActionFailure.noName => l10n.nameBlank,
        TeamActionFailure.notAdmin => l10n.notAdminAnyMore,
      },
    );
  }
}
