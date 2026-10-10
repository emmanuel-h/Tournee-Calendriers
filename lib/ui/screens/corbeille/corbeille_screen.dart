import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/corbeille.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_notifier.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_state.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/recent_time_text.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The Corbeille (PLAN §5.11, Trash mockup), opened from Équipe: the
/// deleted streets and numbers, the latest first, each with who deleted it
/// and when, and « Restaurer », which brings it back with its marks for
/// the whole team. Works offline.
final class CorbeilleScreen extends ConsumerWidget {
  const CorbeilleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final state = ref.watch(corbeilleProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.screenTrash), titleSpacing: 4),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                l10n.corbeilleIntro,
                style: AppTextStyles.body.copyWith(
                  color: colors.muted,
                  height: 1.45,
                ),
              ),
            ),
            if (!state.loading && state.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  l10n.corbeilleEmpty,
                  key: const Key('corbeille.empty'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: colors.muted),
                ),
              ),
            if (state.rows.isNotEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.divider)),
                ),
                child: Column(
                  children: [
                    for (final row in state.rows)
                      _CorbeilleTile(
                        key: ValueKey('corbeille.${_keyOf(row.item)}'),
                        row: row,
                        onRestore: () => unawaited(
                          ref.read(corbeilleProvider.notifier).restore(row),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// `gambetta` for a street, `lilas.14ter` for a number.
  static String _keyOf(CorbeilleItem item) => switch (item) {
    DeletedStreet(:final streetId) => streetId.value,
    RemovedNumber(:final streetId, :final number) =>
      '${streetId.value}.${number.label}',
  };
}

/// « Rue Gambetta » over « 22 numéros · supprimée par Paul · hier », and
/// « Restaurer ».
final class _CorbeilleTile extends StatelessWidget {
  const _CorbeilleTile({super.key, required this.row, required this.onRestore});

  final CorbeilleRow row;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final item = row.item;
    final by = row.removedBy ?? l10n.corbeilleSomeone;
    final when = recentTimeText(l10n, row.removedAt);
    final (title, details) = switch (item) {
      DeletedStreet(:final streetName, :final numberCount) => (
        streetName.text,
        [
          l10n.corbeilleStreetNumbers(numberCount),
          l10n.corbeilleStreetDeletedBy(by),
          when,
        ],
      ),
      RemovedNumber(:final streetName, :final number) => (
        l10n.corbeilleNumberTitle(number.label, streetName.text),
        [l10n.corbeilleNumberDeletedBy(by), when],
      ),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.corbeilleRowHeight),
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: BoxDecoration(
        color: colors.surface,
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
                  style: AppTextStyles.tourneeRowTitle.copyWith(
                    color: colors.ink,
                  ),
                ),
                Text(
                  details.join(' · '),
                  style: AppTextStyles.small.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
          PillButton(
            key: const Key('corbeille.restore'),
            label: l10n.corbeilleRestore,
            semanticsLabel: l10n.corbeilleRestoreSemantics(title),
            strong: true,
            onPressed: onRestore,
          ),
        ],
      ),
    );
  }
}
