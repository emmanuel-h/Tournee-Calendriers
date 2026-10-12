import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/join/join_request_notifier.dart';
import 'package:tournee_calendriers/presentation/join/join_request_state.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_router.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Demande envoyée » (PLAN §5.2, JoinPending mockup): the member waits
/// for an active member of [tournee] to accept them. The screen follows
/// the request by itself: accepted, it opens the start screen on the
/// tournée; refused, it says « Demande refusée » and goes back to
/// « Bienvenue » (or to the start screen, when the phone has one).
/// « Annuler la demande » withdraws it, offline too.
///
/// It is where the app opens while the request waits and the phone holds
/// nothing else; a back arrow leads to the start screen when it does.
final class JoinPendingScreen extends ConsumerWidget {
  const JoinPendingScreen({super.key, required this.tournee});

  final TourneeId tournee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final provider = joinRequestProvider(tournee);
    ref.listen(provider, (_, next) {
      switch (next) {
        case RequestAccepted():
          context.go(AppRoutes.home);
        case RequestClosed(:final refused, :final next):
          if (refused) {
            // Shown above whichever screen comes next.
            showMessageSnackBar(
              ScaffoldMessenger.of(context),
              message: l10n.joinRefused,
            );
          }
          context.go(launchLocation(next));
        case RequestUnknown() || RequestWaiting():
          break;
      }
    });
    final state = ref.watch(provider);
    final waiting = switch (state) {
      final RequestWaiting waiting => waiting,
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: waiting?.canLeave == true
            ? BackButton(
                key: const Key('pending.back'),
                onPressed: () => context.go(AppRoutes.home),
              )
            : null,
      ),
      body: SafeArea(
        child: waiting == null
            ? const SizedBox.shrink()
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    sliver: SliverList.list(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _Clock(
                            label: l10n.joinPendingSemantics,
                            colors: colors,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.screenJoinPending,
                            style: AppTextStyles.pendingTitle.copyWith(
                              color: colors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.joinPreviewTitle(
                            '${waiting.number}',
                            waiting.centre,
                          ),
                          key: const Key('pending.tournee'),
                          style: AppTextStyles.pendingTournee.copyWith(
                            color: colors.muted,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          l10n.joinPendingBody,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: colors.ink,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(color: colors.divider),
                            borderRadius: BorderRadius.circular(
                              AppSizes.alertRadius,
                            ),
                          ),
                          child: Text(
                            l10n.joinPendingOpensItself,
                            style: AppTextStyles.body.copyWith(
                              color: colors.muted,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                        child: SecondaryButton(
                          key: const Key('pending.cancel'),
                          label: l10n.joinPendingCancel,
                          onPressed: () =>
                              unawaited(ref.read(provider.notifier).cancel()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The clock in a yellow ring: the request waits. Said, not only drawn.
final class _Clock extends StatelessWidget {
  const _Clock({required this.label, required this.colors});

  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    excludeSemantics: true,
    child: Container(
      width: AppSizes.pendingBadge,
      height: AppSizes.pendingBadge,
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colors.nobodyHome, width: 2),
      ),
      child: Icon(
        Icons.schedule,
        size: AppSizes.pendingIcon,
        color: colors.ink,
      ),
    ),
  );
}
