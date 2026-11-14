import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_notifier.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_view.dart';
import 'package:tournee_calendriers/ui/components/donation_tile.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Dons de la tournée » of a validated tournée (PLAN §5.20), pushed by
/// « Voir les 19 dons › » of Collecte: its dons newest first, read-only (no
/// › nor button), to compare with the receipts. « ✎ Corriger » is where
/// they change. Read from the phone's copy, offline too.
final class CollecteDonsScreen extends ConsumerWidget {
  const CollecteDonsScreen({super.key, required this.round});

  final RoundId round;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    // `select`: rebuilt only when this tournée changes.
    final shown = ref.watch(
      collecteProvider.select(
        (view) => switch (view) {
          CollecteShown(:final rounds) =>
            rounds.where((each) => each.id == round).firstOrNull,
          CollecteLoading() || CollecteUnavailable() => null,
        },
      ),
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppSizes.titleBarWithSubtitleHeight,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Text(l10n.donsTitle),
            if (shown != null)
              Text(
                roundTotalsText(
                  l10n,
                  DonationTotals.of(shown.donations ?? const []),
                ),
                key: const Key('collecteDons.totals'),
                style: AppTextStyles.small.copyWith(color: colors.muted),
              ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const Key('collecteDons.list'),
          children: [
            Divider(height: 1, color: colors.divider),
            for (final (position, row) in (shown?.donationRows ?? []).indexed)
              DonationTile(
                key: ValueKey('collecteDons.row.$position'),
                donation: row.donation,
              ),
          ],
        ),
      ),
    );
  }
}
