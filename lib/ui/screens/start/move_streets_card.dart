import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/move_streets/move_streets_notifier.dart';
import 'package:tournee_calendriers/presentation/move_streets/move_streets_state.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The card at the top of the start screen while a tournée is open and
/// the phone still holds its streets from before (PLAN §5.0): « 12 rues
/// sont enregistrées sur ce téléphone. », « Les ajouter à la tournée »
/// and « Plus tard »; « Ajout en cours… 3/12 » while they go. Nothing at
/// all the rest of the time.
final class MoveStreetsCard extends ConsumerWidget {
  const MoveStreetsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = AppTextStyles.body.copyWith(color: colors.ink);
    return switch (ref.watch(moveStreetsProvider)) {
      NoStreetsToMove() => const SizedBox.shrink(),
      StreetsToMove(:final count) => _Frame(
        children: [
          Text(l10n.moveStreetsCount(count), style: text),
          PrimaryButton(
            key: const Key('start.moveStreets'),
            label: l10n.moveStreetsAction(count),
            compact: true,
            onPressed: () => unawaited(_move(context, ref)),
          ),
          TextButton(
            key: const Key('start.moveStreetsLater'),
            style: TextButton.styleFrom(
              foregroundColor: colors.ink,
              minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
              textStyle: AppTextStyles.pill,
            ),
            // `ref.read`: an intent, sent once.
            onPressed: ref.read(moveStreetsProvider.notifier).later,
            child: Text(l10n.moveStreetsLater),
          ),
        ],
      ),
      MovingStreets(:final done, :final total) => _Frame(
        children: [
          Text(
            l10n.moveStreetsProgress(done, total),
            key: const Key('start.moveStreetsProgress'),
            style: text,
          ),
        ],
      ),
    };
  }

  /// Moves the streets, then says what it did.
  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    // Taken before waiting: the snackbar shows on this screen's messenger
    // even if the card itself has gone meanwhile.
    final messenger = ScaffoldMessenger.of(context);
    final summary = await ref.read(moveStreetsProvider.notifier).move();
    if (summary == null) return;
    showMessageSnackBar(messenger, message: movedStreetsMessage(l10n, summary));
  }
}

/// « 12 rues ajoutées à la tournée », or « 10 rues ajoutées, 2 déjà dans
/// la tournée » when the tournée already had some.
String movedStreetsMessage(AppLocalizations l10n, MovedSummary summary) =>
    switch (summary) {
      MovedSummary(:final moved, alreadyThere: 0) => l10n.moveStreetsDone(
        moved,
      ),
      MovedSummary(:final moved, :final alreadyThere) =>
        l10n.moveStreetsDoneSome(moved, alreadyThere),
    };

/// The outlined card holding the message and its buttons.
final class _Frame extends StatelessWidget {
  const _Frame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      key: const Key('start.moveStreetsCard'),
      margin: const EdgeInsets.fromLTRB(
        AppSizes.gutter,
        12,
        AppSizes.gutter,
        0,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line, width: AppSizes.borderWidth),
        borderRadius: BorderRadius.circular(AppSizes.moveStreetsCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: children,
      ),
    );
  }
}
