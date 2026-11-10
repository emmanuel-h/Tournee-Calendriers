import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/presentation/round/round_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/confirm_dialog.dart';
import 'package:tournee_calendriers/ui/components/money_lines.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/components/open_chevron.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Bilan de la tournée » (PLAN §5.13, `docs/mockups/RunRecap.dc.html`),
/// opened by « ■ Terminer »: « Samedi 24 octobre, de 14 h 05 à 18 h 20 »,
/// three figures (« 23 maisons visitées », « 19 dons », « 2 calendriers
/// offerts »), « ARGENT RÉCOLTÉ » per method and « Total », « Voir les dons
/// › »; then « Valider la tournée », which asks first, sends the summary
/// (queued offline) and goes back to Accueil, « Continuer la tournée »,
/// which only goes back, and « Abandonner la tournée », which asks first,
/// forgets a tournée started by mistake and goes back to Accueil (#136).
///
/// A `State`: the end of the tournée is « now », read from the clock once
/// the screen shows.
final class RoundRecapScreen extends ConsumerStatefulWidget {
  const RoundRecapScreen({super.key});

  @override
  ConsumerState<RoundRecapScreen> createState() => _RoundRecapScreenState();
}

final class _RoundRecapScreenState extends ConsumerState<RoundRecapScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: a provider must not change while the tree is
    // being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(roundProvider.notifier).tick();
    });
  }

  @override
  Widget build(BuildContext context) {
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
            Text(l10n.recapTitle),
            if (round is RoundOn)
              Text(
                _when(l10n, round),
                key: const Key('recap.when'),
                style: AppTextStyles.small.copyWith(color: colors.muted),
              ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: switch (round) {
          RoundLoading() || RoundOff() => const SizedBox.shrink(),
          final RoundOn round => _Recap(
            round: round,
            onValidate: () => unawaited(_validate()),
            onAbandon: () => unawaited(_abandon()),
          ),
        },
      ),
    );
  }

  /// « Samedi 24 octobre, de 14 h 05 à 18 h 20 », the day with a capital.
  static String _when(AppLocalizations l10n, RoundOn round) {
    final text = l10n.recapWhen(
      round.startedAt,
      clockTimeText(l10n, round.startedAt),
      clockTimeText(l10n, round.now),
    );
    return text[0].toUpperCase() + text.substring(1);
  }

  /// « Valider la tournée ? — Vous ne pourrez plus la modifier. », then
  /// the summary is sent and Accueil shows, without a tournée.
  Future<void> _validate() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      name: 'recap.confirm',
      title: l10n.recapConfirmTitle,
      body: l10n.recapConfirmBody,
      confirmLabel: l10n.recapConfirmOk,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    // Kept on the phone in a moment, and queued for the secteur while
    // offline; Accueil then shows no tournée.
    await ref.read(roundProvider.notifier).validate();
    if (mounted) context.go(AppRoutes.home);
  }

  /// « Abandonner la tournée ? — Ses dons seront perdus. Les maisons
  /// marquées restent marquées. », then the phone forgets the tournée,
  /// sends nothing, and Accueil shows with its top bar again. Offline too:
  /// only the phone's file changes.
  Future<void> _abandon() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      name: 'recap.abandonConfirm',
      title: l10n.recapAbandonTitle,
      body: l10n.recapAbandonBody,
      confirmLabel: l10n.recapAbandonOk,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(roundProvider.notifier).abandon();
    if (mounted) context.go(AppRoutes.home);
  }
}

/// The figures, the money and the three buttons.
final class _Recap extends StatelessWidget {
  const _Recap({
    required this.round,
    required this.onValidate,
    required this.onAbandon,
  });

  final RoundOn round;
  final VoidCallback onValidate;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final totals = round.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.gutter,
                ),
                // `IntrinsicHeight`: the three boxes as tall as the
                // tallest, when a label takes two lines.
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      _Figure(
                        key: const Key('recap.houses'),
                        value: round.housesVisited,
                        label: l10n.recapHouses(round.housesVisited),
                        color: colors.doneInk,
                      ),
                      _Figure(
                        key: const Key('recap.dons'),
                        value: totals.count,
                        label: l10n.recapDons(totals.count),
                        color: colors.ink,
                      ),
                      _Figure(
                        key: const Key('recap.free'),
                        value: totals.free,
                        label: l10n.recapFree(totals.free),
                        color: colors.ink,
                      ),
                    ],
                  ),
                ),
              ),
              SectionHeader(
                l10n.recapMoney,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              ),
              _Money(totals: totals),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            12,
            AppSizes.gutter,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              PrimaryButton(
                key: const Key('recap.validate'),
                label: l10n.recapValidate,
                onPressed: onValidate,
              ),
              SecondaryButton(
                key: const Key('recap.continue'),
                label: l10n.recapContinue,
                compact: true,
                onPressed: () => context.pop(),
              ),
              // Text only, in red: the way out of a tournée started by
              // mistake, set apart from the two buttons of a real one.
              TextButton(
                key: const Key('recap.abandon'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.accent,
                  minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
                ),
                onPressed: onAbandon,
                child: Text(l10n.recapAbandon),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One figure of the « Bilan »: the number large, its words under it.
/// Screen readers hear « 23 maisons visitées ».
final class _Figure extends StatelessWidget {
  const _Figure({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: MergeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.divider),
            borderRadius: BorderRadius.circular(AppSizes.roundCardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: AppTextStyles.recapFigure.copyWith(color: color),
              ),
              Text(
                label,
                style: AppTextStyles.small.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Espèces · 15 dons · 210 € », « Chèques », « Carte bancaire »,
/// « Total », then « Voir les dons › ».
final class _Money extends StatelessWidget {
  const _Money({required this.totals});

  final DonationTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Material(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyTotalsLines(totals: totals, keyPrefix: 'recap'),
          Divider(height: 1, color: colors.divider),
          MergeSemantics(
            child: InkWell(
              key: const Key('recap.seeDons'),
              onTap: () => unawaited(context.push(AppRoutes.roundDons)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.choiceRowHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.gutter,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.recapSeeDons,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: colors.ink,
                          ),
                        ),
                      ),
                      OpenChevron(
                        height: AppSizes.smallIcon,
                        color: colors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
