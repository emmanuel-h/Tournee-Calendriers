import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_state.dart';
import 'package:tournee_calendriers/ui/components/dashed_outline.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// Opens « Mes tournées » (tap the title, or Paramètres → Mes tournées,
/// PLAN §5.3, Switcher mockup).
Future<void> showMyTourneesSheet(BuildContext context) =>
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => const MyTourneesSheet(),
    );

/// The member's tournées: the open one (● and ✓), the others (a tap opens
/// one at once, and the app reopens it next time), and their requests not
/// accepted yet, which cannot be opened.
final class MyTourneesSheet extends ConsumerWidget {
  const MyTourneesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final rows = ref.watch(myTourneesProvider).rows;
    return SheetScaffold(
      title: l10n.myTourneesTitle,
      spacing: 6,
      children: [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.myTourneesEmpty,
              key: const Key('myTournees.empty'),
              style: AppTextStyles.body.copyWith(color: colors.muted),
            ),
          ),
        for (final row in rows)
          _TourneeRowTile(
            key: ValueKey('myTournees.${row.id.value}'),
            row: row,
            onTap: switch (row.status) {
              TourneeRowStatus.open => () => Navigator.of(context).pop(),
              TourneeRowStatus.closed => () {
                unawaited(ref.read(myTourneesProvider.notifier).open(row.id));
                Navigator.of(context).pop();
              },
              TourneeRowStatus.pending => null,
            },
          ),
      ],
    );
  }
}

/// One tournée: its mark, « Tournée 12 · 2026 » over its centre, and ✓
/// when it is the open one. Never told by colour alone: the open one has
/// ✓ and a filled mark, a request a dashed mark and its own words.
final class _TourneeRowTile extends StatelessWidget {
  const _TourneeRowTile({super.key, required this.row, required this.onTap});

  final TourneeRow row;

  /// Null for a request: the row cannot be tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final title = l10n.tourneeTitle('${row.number}', '${row.campaign}');
    final (subtitle, label) = switch (row.status) {
      TourneeRowStatus.open => (
        row.centre,
        l10n.myTourneesOpenSemantics(title, row.centre),
      ),
      TourneeRowStatus.closed => (
        row.centre,
        l10n.myTourneesClosedSemantics(title, row.centre),
      ),
      TourneeRowStatus.pending => (
        l10n.myTourneesPending(row.centre),
        l10n.myTourneesPendingSemantics(title, row.centre),
      ),
    };
    final ink = row.status == TourneeRowStatus.pending
        ? colors.muted
        : colors.ink;
    return Semantics(
      button: onTap != null,
      selected: row.status == TourneeRowStatus.open,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSizes.tourneeRowHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            spacing: 14,
            children: [
              _TourneeMark(status: row.status),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.tourneeRowTitle.copyWith(color: ink),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.small.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              if (row.status == TourneeRowStatus.open)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: StatusGlyph(
                    StatusGlyphs.done,
                    size: AppSizes.segmentGlyph,
                    color: colors.done,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ● for the open tournée, ○ for another, a dashed ○ for a request.
final class _TourneeMark extends StatelessWidget {
  const _TourneeMark({required this.status});

  final TourneeRowStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const side = AppSizes.tourneeMark;
    return switch (status) {
      TourneeRowStatus.open => Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.done, width: 2),
        ),
        child: Container(
          width: AppSizes.tourneeMarkDot,
          height: AppSizes.tourneeMarkDot,
          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.done),
        ),
      ),
      TourneeRowStatus.closed => Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.muted, width: 2),
        ),
      ),
      TourneeRowStatus.pending => CustomPaint(
        size: const Size.square(side),
        painter: DashedOutlinePainter(colors.muted, radius: side / 2),
      ),
    };
  }
}
