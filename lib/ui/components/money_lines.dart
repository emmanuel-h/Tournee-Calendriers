import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// How a [MoneyLine] looks.
enum MoneyLineLook {
  /// « Espèces · 15 dons · 210 € »: the method in bold.
  method,

  /// « Calendriers offerts · 3 »: the name in plain type, no amount.
  plain,

  /// « Total · 19 dons · 280 € »: larger type, the count in ink, on the
  /// ground colour, without a line under it.
  total,

  /// A method under an unfolded tournée of the Collecte screen: indented,
  /// lower, smaller, with the empty column of the ▸ / ▾ of the tournées.
  detail,
}

/// One line of a table of money (« ARGENT RÉCOLTÉ » of the « Bilan », the
/// totals and the tournées of « Collecte 2026 »): a name, a count and an
/// amount in a column of its own, so the amounts line up. Screen readers
/// hear the line as one: « Espèces, 15 dons, 210 € ».
final class MoneyLine extends StatelessWidget {
  const MoneyLine({
    super.key,
    required this.name,
    required this.count,
    this.cents,
    this.look = MoneyLineLook.method,
  });

  final String name;

  /// « 15 dons », or a bare « 3 » of calendars.
  final String count;

  /// The amount; none on a [MoneyLineLook.plain] line, whose column stays
  /// empty.
  final int? cents;
  final MoneyLineLook look;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final cents = this.cents;
    final (nameStyle, countStyle, amountStyle) = switch (look) {
      MoneyLineLook.method => (
        AppTextStyles.button,
        AppTextStyles.streetCounts.copyWith(color: colors.muted),
        AppTextStyles.donationAmount,
      ),
      MoneyLineLook.plain => (
        AppTextStyles.bodyLarge,
        AppTextStyles.streetCounts.copyWith(color: colors.muted),
        AppTextStyles.donationAmount,
      ),
      MoneyLineLook.total => (
        AppTextStyles.button,
        AppTextStyles.rowCount.copyWith(color: colors.ink),
        AppTextStyles.recapTotal,
      ),
      MoneyLineLook.detail => (
        AppTextStyles.streetCounts,
        AppTextStyles.streetCounts.copyWith(color: colors.muted),
        AppTextStyles.collecteDetailAmount,
      ),
    };
    final detail = look == MoneyLineLook.detail;
    final line = Container(
      constraints: BoxConstraints(
        minHeight: detail
            ? AppSizes.collecteDetailLineHeight
            : AppSizes.recapLineHeight,
      ),
      padding: EdgeInsets.only(
        left: detail ? AppSizes.collecteDetailIndent : AppSizes.gutter,
        right: AppSizes.gutter,
      ),
      decoration: look == MoneyLineLook.total
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Text(name, style: nameStyle.copyWith(color: colors.ink)),
          ),
          Text(count, style: countStyle),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSizes.recapAmountWidth,
            ),
            child: Text(
              cents == null ? '' : eurosText(l10n, cents),
              textAlign: TextAlign.right,
              style: amountStyle.copyWith(color: colors.ink),
            ),
          ),
          if (detail) const SizedBox(width: AppSizes.collecteChevronWidth),
        ],
      ),
    );
    return MergeSemantics(
      child: look == MoneyLineLook.total
          ? ColoredBox(color: colors.ground, child: line)
          : line,
    );
  }
}

/// The money of [totals] as a table on the surface colour: « Espèces »,
/// « Chèques », « Carte bancaire », with [showFree] « Calendriers
/// offerts », then « Total ». Each line has the key `<keyPrefix>.cash`,
/// `.cheque`, `.card`, `.free` and `.total`, for the tests.
final class MoneyTotalsLines extends StatelessWidget {
  const MoneyTotalsLines({
    super.key,
    required this.totals,
    required this.keyPrefix,
    this.showFree = false,
  });

  final DonationTotals totals;
  final String keyPrefix;

  /// The calendars given for free have a line of their own (Collecte; the
  /// « Bilan » shows them in its figures instead).
  final bool showFree;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: colors.divider),
        MoneyLine(
          key: Key('$keyPrefix.cash'),
          name: l10n.paymentCash,
          count: l10n.donCount(totals.cash.count),
          cents: totals.cash.cents,
        ),
        MoneyLine(
          key: Key('$keyPrefix.cheque'),
          name: l10n.paymentCheques,
          count: l10n.donCount(totals.cheque.count),
          cents: totals.cheque.cents,
        ),
        MoneyLine(
          key: Key('$keyPrefix.card'),
          name: l10n.paymentCardLong,
          count: l10n.donCount(totals.card.count),
          cents: totals.card.cents,
        ),
        if (showFree)
          MoneyLine(
            key: Key('$keyPrefix.free'),
            name: l10n.collecteFree,
            count: '${totals.free}',
            look: MoneyLineLook.plain,
          ),
        MoneyLine(
          key: Key('$keyPrefix.total'),
          name: l10n.recapTotal,
          count: l10n.donCount(totals.count),
          cents: totals.cents,
          look: MoneyLineLook.total,
        ),
      ],
    );
  }
}
