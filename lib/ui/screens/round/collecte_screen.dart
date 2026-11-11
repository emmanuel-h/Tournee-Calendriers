import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_notifier.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_view.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/confirm_dialog.dart';
import 'package:tournee_calendriers/ui/components/money_lines.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Collecte 2026 » (PLAN §5.13, `docs/mockups/Cash.dc.html`), pushed by
/// Équipe: « Secteur 49 · tournées validées », « TOTAL DES 4 TOURNÉES »
/// per method with « Calendriers offerts » and « Total », then
/// « TOURNÉES », each validated tournée newest first, **without its
/// member**; a tap unfolds its methods. Read from the phone's copy, so it
/// opens offline; every member sees it.
///
/// This phone's tournées the server does not have yet (PLAN §5.16,
/// `docs/mockups/CashUnsent.dc.html`) sit between the totals and
/// « TOURNÉES », under « PAS ENCORE ENVOYÉES (2) », each with « ⏳ En
/// attente d'envoi » or « ⚠ Refusée par le serveur » and its « Réessayer »
/// and « Effacer »; the totals leave them out and say so.
final class CollecteScreen extends ConsumerWidget {
  const CollecteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final view = ref.watch(collecteProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppSizes.titleBarWithSubtitleHeight,
        titleSpacing: 4,
        title: switch (view) {
          CollecteShown(:final campaign, :final number) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              Text(l10n.collecteTitle('$campaign')),
              Text(
                l10n.collecteSubtitle('$number'),
                key: const Key('collecte.subtitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.small.copyWith(color: colors.muted),
              ),
            ],
          ),
          CollecteLoading() || CollecteUnavailable() => const SizedBox.shrink(),
        },
      ),
      body: SafeArea(
        top: false,
        child: switch (view) {
          final CollecteShown view => _Collecte(view: view),
          CollecteLoading() => const SizedBox.shrink(),
          CollecteUnavailable() => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                l10n.collecteUnavailable,
                key: const Key('collecte.message'),
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: colors.muted),
              ),
            ),
          ),
        },
      ),
    );
  }
}

/// The totals, the tournées and the footnote, which scroll.
final class _Collecte extends StatelessWidget {
  const _Collecte({required this.view});

  final CollecteShown view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    const headerPadding = EdgeInsets.fromLTRB(20, 18, 20, 8);
    return ListView(
      children: [
        SectionHeader(
          l10n.collecteTotalHeader(view.rounds.length),
          padding: headerPadding,
        ),
        Material(
          color: colors.surface,
          child: MoneyTotalsLines(
            totals: view.totals,
            keyPrefix: 'collecte',
            showFree: true,
          ),
        ),
        if (view.unsent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              l10n.collecteUnsentLeftOut,
              key: const Key('collecte.unsentLeftOut'),
              style: AppTextStyles.small.copyWith(color: colors.muted),
            ),
          ),
          SectionHeader(
            l10n.collecteUnsentHeader(view.unsent.length),
            padding: headerPadding,
          ),
          Divider(height: 1, color: colors.divider),
          for (final unsent in view.unsent)
            _RoundRow(
              key: ValueKey('collecte.unsent.${unsent.round.id.value}'),
              round: unsent.round,
              unsent: unsent.state,
            ),
        ],
        SectionHeader(l10n.collecteRoundsHeader, padding: headerPadding),
        Divider(height: 1, color: colors.divider),
        for (final round in view.rounds)
          _RoundRow(
            key: ValueKey('collecte.round.${round.id.value}'),
            round: round,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Text(
            l10n.collecteNeverChanged,
            key: const Key('collecte.neverChanged'),
            style: AppTextStyles.small.copyWith(color: colors.muted),
          ),
        ),
      ],
    );
  }
}

/// A validated tournée: « Sam. 24 oct. · 14:05 → 18:20 » over « 23
/// maisons, 19 dons », its total and ▸; a tap unfolds its methods (▾).
/// One not yet sent ([unsent]) has its badge under them, and once refused
/// « Réessayer » and « Effacer ».
///
/// A `ConsumerStatefulWidget` holds whether it is open, as a member's row
/// of Équipe does: only this row needs to know, and the key of the row
/// (the tournée's id) keeps it with its tournée when another one arrives.
/// `Consumer`: its buttons reach the Collecte notifier.
final class _RoundRow extends ConsumerStatefulWidget {
  const _RoundRow({super.key, required this.round, this.unsent});

  final CollecteRound round;

  /// Where a tournée not yet sent stands; null for one the secteur has.
  final UnsentState? unsent;

  @override
  ConsumerState<_RoundRow> createState() => _RoundRowState();
}

final class _RoundRowState extends ConsumerState<_RoundRow> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final round = widget.round;
    final totals = round.totals;
    final when = _when(l10n, round);
    final amount = eurosText(l10n, totals.cents);
    final unsent = widget.unsent;
    final spokenState = switch (unsent) {
      null => null,
      UnsentState.waiting => l10n.collecteUnsentWaitingSpoken,
      UnsentState.refused => l10n.collecteUnsentRefusedSpoken,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          label: switch ((_open, spokenState)) {
            (false, null) => l10n.collecteRoundShow(when, amount),
            (true, null) => l10n.collecteRoundHide(when, amount),
            (false, final state?) => l10n.collecteUnsentShow(
              when,
              amount,
              state,
            ),
            (true, final state?) => l10n.collecteUnsentHide(
              when,
              amount,
              state,
            ),
          },
          // The label says it all: the texts and ▸ are not read again.
          excludeSemantics: true,
          child: Material(
            color: colors.surface,
            child: InkWell(
              key: const Key('collecte.round.toggle'),
              onTap: () => setState(() => _open = !_open),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.collecteRoundHeight,
                ),
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.divider)),
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(
                            when,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: colors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l10n.collecteRoundLine(
                              round.housesVisited,
                              l10n.donCount(totals.count),
                            ),
                            style: AppTextStyles.small.copyWith(
                              color: colors.muted,
                            ),
                          ),
                          if (unsent != null) _UnsentBadge(state: unsent),
                        ],
                      ),
                    ),
                    Text(
                      amount,
                      style: AppTextStyles.donationAmount.copyWith(
                        color: colors.ink,
                      ),
                    ),
                    SizedBox(
                      width: AppSizes.collecteChevronWidth,
                      child: Text(
                        _open ? '▾' : '▸',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: colors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (unsent == UnsentState.refused)
          _RefusedActions(round: round, when: when),
        if (_open)
          ColoredBox(
            key: const Key('collecte.round.methods'),
            color: colors.ground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MoneyLine(
                  name: l10n.paymentCash,
                  count: l10n.donCount(totals.cash.count),
                  cents: totals.cash.cents,
                  look: MoneyLineLook.detail,
                ),
                MoneyLine(
                  name: l10n.paymentCheques,
                  count: l10n.donCount(totals.cheque.count),
                  cents: totals.cheque.cents,
                  look: MoneyLineLook.detail,
                ),
                MoneyLine(
                  name: l10n.paymentCardLong,
                  count: l10n.donCount(totals.card.count),
                  cents: totals.card.cents,
                  look: MoneyLineLook.detail,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// « Sam. 24 oct. · 14:05 → 18:20 », the day with a capital.
  static String _when(AppLocalizations l10n, CollecteRound round) {
    final text = l10n.collecteRoundWhen(
      round.startedAt,
      round.startedAt,
      round.endedAt,
    );
    return text[0].toUpperCase() + text.substring(1);
  }
}

/// « ⏳ En attente d'envoi » (the come-back blue) or « ⚠ Refusée par le
/// serveur » (red, outlined): the glyph and the words say it, never the
/// colour alone.
final class _UnsentBadge extends StatelessWidget {
  const _UnsentBadge({required this.state});

  final UnsentState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final (text, ink, fill, border) = switch (state) {
      UnsentState.waiting => (
        l10n.collecteUnsentWaiting,
        colors.onComeBack,
        colors.comeBack,
        null,
      ),
      UnsentState.refused => (
        l10n.collecteUnsentRefused,
        colors.accent,
        colors.alert,
        colors.accent,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        key: const Key('collecte.unsent.badge'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppSizes.badgeRadius),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Text(
          text,
          style: AppTextStyles.small.copyWith(
            color: ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// « Réessayer » and « Effacer » (red) under a tournée the server refused.
/// « Effacer » asks first: its figures are lost.
final class _RefusedActions extends ConsumerWidget {
  const _RefusedActions({required this.round, required this.when});

  final CollecteRound round;

  /// « Dim. 25 oct. · 10:00 → 11:30 », for screen readers.
  final String when;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final notifier = ref.read(collecteProvider.notifier);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        spacing: 10,
        children: [
          PillButton(
            key: const Key('collecte.unsent.retry'),
            label: l10n.retry,
            strong: true,
            semanticsLabel: l10n.collecteRetrySpoken(when),
            onPressed: () => unawaited(notifier.retry(round.id)),
          ),
          Semantics(
            button: true,
            label: l10n.collecteEraseSpoken(when),
            excludeSemantics: true,
            child: TextButton(
              key: const Key('collecte.unsent.erase'),
              style: TextButton.styleFrom(
                foregroundColor: colors.accent,
                textStyle: AppTextStyles.pill,
              ),
              onPressed: () => unawaited(_erase(context, notifier)),
              child: Text(l10n.collecteErase),
            ),
          ),
        ],
      ),
    );
  }

  /// « Effacer la tournée ? — Ses chiffres seront perdus… », then the
  /// phone forgets it.
  Future<void> _erase(BuildContext context, CollecteNotifier notifier) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      name: 'collecte.eraseConfirm',
      title: l10n.collecteEraseTitle,
      body: l10n.collecteEraseBody,
      confirmLabel: l10n.collecteEraseOk,
      destructive: true,
    );
    if (confirmed) await notifier.erase(round.id);
  }
}
