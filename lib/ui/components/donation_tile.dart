import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/components/open_chevron.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// One don of a list of dons (« Dons de la tournée », « Corriger la
/// tournée », PLAN §5.13, §5.20): its amount in a column of its own, so the
/// methods line up, then the method (« Espèces »), or « Calendrier offert »
/// across both; a « › » at the end when a tap opens it ([onTap]). Without
/// [onTap] it is read-only (a validated tournée's list in « Collecte »).
/// Screen readers hear one line, a button when it opens.
final class DonationTile extends StatelessWidget {
  const DonationTile({super.key, required this.donation, this.onTap});

  final Donation donation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final onTap = this.onTap;
    final (amount, words) = switch (donation) {
      PaidDonation(:final method, :final amount) => (
        eurosText(l10n, amount.cents),
        methodName(l10n, method),
      ),
      FreeCalendar() => (null, l10n.donationFreeCalendar),
    };
    final line = Container(
      constraints: const BoxConstraints(minHeight: AppSizes.choiceRowHeight),
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
          if (onTap != null)
            OpenChevron(height: AppSizes.smallIcon, color: colors.muted),
        ],
      ),
    );
    // `MergeSemantics`: the amount and the method are heard as one line,
    // with the button when there is one.
    return MergeSemantics(
      child: Material(
        color: colors.surface,
        child: onTap == null ? line : InkWell(onTap: onTap, child: line),
      ),
    );
  }
}
