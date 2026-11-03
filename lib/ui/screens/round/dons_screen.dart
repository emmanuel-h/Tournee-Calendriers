import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/presentation/round/round_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/components/open_chevron.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/round/donation_sheet.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Dons de la tournée » (PLAN §5.13, `docs/mockups/RunDons.dc.html`):
/// « 19 dons · 280 € » under the title, the dons newest first (« 10 € ·
/// Espèces › », « Calendrier offert › »), each opening « Modifier le don »;
/// « Ajouter un don » pinned at the bottom opens « Nouveau don », for money
/// from someone with no house. Kept on the phone only, offline too.
final class DonsScreen extends ConsumerWidget {
  const DonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final round = ref.watch(roundProvider);
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
            if (round is RoundOn)
              Text(
                roundTotalsText(l10n, round.totals),
                key: const Key('dons.totals'),
                style: AppTextStyles.small.copyWith(color: colors.muted),
              ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        // No tournée (validated meanwhile on another screen): nothing to
        // list, nothing to add to.
        child: switch (round) {
          RoundLoading() || RoundOff() => const SizedBox.shrink(),
          RoundOn(:final donations) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Divider(height: 1, color: colors.divider),
              Expanded(
                child: donations.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.donsEmpty,
                          key: const Key('dons.empty'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            color: colors.muted,
                          ),
                        ),
                      )
                    : ListView(
                        key: const Key('dons.list'),
                        children: [
                          for (final (position, row) in donations.indexed)
                            _DonationTile(
                              key: ValueKey('dons.row.$position'),
                              donation: row.donation,
                              onTap: () => unawaited(
                                showDonationSheet(
                                  context,
                                  row: row,
                                  onSave: (donation) => ref
                                      .read(roundProvider.notifier)
                                      .changeDonation(row.index, donation),
                                  onRemove: () => ref
                                      .read(roundProvider.notifier)
                                      .removeDonation(row.index),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              Divider(height: 1, color: colors.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.gutter,
                  12,
                  AppSizes.gutter,
                  24,
                ),
                child: PrimaryButton(
                  key: const Key('dons.add'),
                  label: l10n.addDonation,
                  onPressed: () => unawaited(
                    showDonationSheet(
                      context,
                      onSave: ref.read(roundProvider.notifier).addDonation,
                    ),
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

/// One don: its amount in a column of its own, so the methods line up,
/// then the method (« Espèces »), or « Calendrier offert » across both; a
/// « › » at the end. Screen readers hear one button.
final class _DonationTile extends StatelessWidget {
  const _DonationTile({super.key, required this.donation, required this.onTap});

  final Donation donation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final (amount, words) = switch (donation) {
      PaidDonation(:final method, :final amount) => (
        eurosText(l10n, amount.cents),
        methodName(l10n, method),
      ),
      FreeCalendar() => (null, l10n.donationFreeCalendar),
    };
    // `MergeSemantics`: the amount and the method are heard with the
    // button.
    return MergeSemantics(
      child: Material(
        color: colors.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.choiceRowHeight,
            ),
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              spacing: 12,
              children: [
                SizedBox(
                  width: AppSizes.donationAmountWidth,
                  child: amount == null
                      ? null
                      : Text(
                          amount,
                          textAlign: TextAlign.right,
                          style: AppTextStyles.donationAmount.copyWith(
                            color: colors.ink,
                          ),
                        ),
                ),
                Expanded(
                  child: Text(
                    words,
                    style: AppTextStyles.body.copyWith(color: colors.ink),
                  ),
                ),
                OpenChevron(height: AppSizes.smallIcon, color: colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
