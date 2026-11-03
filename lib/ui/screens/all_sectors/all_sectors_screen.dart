import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/all_sectors/all_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/all_sectors/all_sectors_state.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Tous les secteurs » (PLAN §5.12, AllSectors mockup), for admins:
/// every tournée of the app under its centre de secours, with its members,
/// its waiting requests (a red dot) and « vous en êtes membre ». A tap opens
/// it on the normal screens. Needs the network: offline it says so and
/// offers « Réessayer ».
final class AllSectorsScreen extends ConsumerWidget {
  const AllSectorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final state = ref.watch(allSectorsProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppSizes.titleBarWithSubtitleHeight,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Text(l10n.mySectorsAll),
            if (state case AllSectorsShown(:final count))
              Text(
                l10n.allSectorsSubtitle(count),
                key: const Key('allSectors.subtitle'),
                style: AppTextStyles.small.copyWith(color: colors.muted),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: switch (state) {
          AllSectorsLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          AllSectorsOffline() => _Problem(
            message: l10n.allSectorsOffline,
            messageKey: const Key('allSectors.offline'),
            onRetry: () =>
                unawaited(ref.read(allSectorsProvider.notifier).retry()),
          ),
          // Asking again would be refused again: no « Réessayer ».
          AllSectorsNotAdmin() => _Problem(
            message: l10n.notAdminAnyMore,
            messageKey: const Key('allSectors.notAdmin'),
          ),
          AllSectorsShown(:final groups) => ListView(
            children: [
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSizes.gutter),
                  child: Text(
                    l10n.allSectorsEmpty,
                    key: const Key('allSectors.empty'),
                    style: AppTextStyles.body.copyWith(color: colors.muted),
                  ),
                ),
              for (final group in groups) ...[
                SectionHeader(group.centre),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.divider)),
                  ),
                  child: Column(
                    children: [
                      for (final row in group.rows)
                        _OverviewTile(
                          key: ValueKey('allSectors.${row.id.value}'),
                          row: row,
                          onTap: () async {
                            await ref
                                .read(allSectorsProvider.notifier)
                                .open(row.id);
                            // Its screens are the normal ones: Accueil.
                            if (context.mounted) context.go(AppRoutes.home);
                          },
                        ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Text(
                  l10n.allSectorsHint,
                  style: AppTextStyles.small.copyWith(
                    color: colors.muted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}

/// Why the list cannot be shown, centred: « Pas de réseau : la liste ne
/// peut pas être affichée. » with « Réessayer » ([onRetry]), or « Vous
/// n'êtes plus administrateur. » alone.
final class _Problem extends StatelessWidget {
  const _Problem({
    required this.message,
    required this.messageKey,
    this.onRetry,
  });

  final String message;
  final Key messageKey;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final onRetry = this.onRetry;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                key: messageKey,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: colors.muted),
              ),
            ),
            if (onRetry != null)
              PillButton(
                key: const Key('allSectors.retry'),
                label: l10n.retry,
                onPressed: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

/// « Tournée 12 · 2026 › » over « 3 membres · 1 demande en attente », the
/// red dot then said by screen readers; « Aucun membre » in red, with its
/// own words so not by colour alone.
final class _OverviewTile extends StatelessWidget {
  const _OverviewTile({super.key, required this.row, required this.onTap});

  final OverviewRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final title = l10n.sectorTitle('${row.number}', '${row.campaign}');
    final members = l10n.allSectorsMembers(row.members);
    final mine = row.iAmIn ? l10n.allSectorsMine(members) : members;
    final details = row.waitingRequests > 0
        ? l10n.allSectorsWaiting(mine, row.waitingRequests)
        : mine;
    return Semantics(
      button: true,
      label: l10n.allSectorsRowSemantics(title, details),
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.sectorRowHeight,
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.sectorRowTitle.copyWith(
                          color: colors.ink,
                        ),
                      ),
                      Text(
                        details,
                        style: AppTextStyles.small.copyWith(
                          color: row.members == 0
                              ? colors.accent
                              : colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (row.waitingRequests > 0)
                  Container(
                    key: Key('allSectors.${row.id.value}.dot'),
                    width: AppSizes.waitingDot,
                    height: AppSizes.waitingDot,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent,
                    ),
                  ),
                Icon(
                  Icons.chevron_right,
                  size: AppSizes.smallIcon,
                  color: colors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
