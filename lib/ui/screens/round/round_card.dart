import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/round/round_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

// The tournée on Accueil and on the street screen (PLAN §5.13, mockups
// RunStart, RunHome, RunStreet).

/// The top of Accueil's list, under the totals: « ▶ Commencer une
/// tournée » for a member of the team while none is on (RunStart), the
/// tournée's card while one is (RunHome); nothing for an admin visiting the
/// secteur.
final class RoundPanelEntry extends ConsumerWidget {
  const RoundPanelEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(roundProvider)) {
        RoundLoading() || RoundOff(canStart: false) => const SizedBox.shrink(),
        RoundOff(canStart: true) => const _StartButton(),
        final RoundOn round => _HomeCard(round: round),
      };
}

/// « ▶ Commencer une tournée », outlined in ink, the ▶ in red.
final class _StartButton extends ConsumerWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SecondaryButton(
        key: const Key('round.start'),
        label: l10n.roundStart,
        strong: true,
        compact: true,
        leading: Icon(Icons.play_arrow, color: AppColors.of(context).accent),
        onPressed: () => unawaited(_start(context, ref)),
      ),
    );
  }

  /// Starts the tournée; the card takes the button's place. Refused only
  /// when one is on in another secteur (the button shows only to a member
  /// of the team): one at a time on a phone.
  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).roundAlreadyOnElsewhere;
    switch (await ref.read(roundProvider.notifier).start()) {
      case StartOutcome.alreadyOnElsewhere:
        showMessageSnackBar(messenger, message: message);
      case StartOutcome.started || StartOutcome.refused:
        break;
    }
  }
}

/// The tournée's card on Accueil: « ● En tournée depuis 1 h 20 », « 19 dons
/// · 280 € » and « Voir les dons › », which opens « Dons de la tournée »;
/// « ■ Terminer », which opens the « Bilan ».
///
/// A `State`: it reads the clock again every 30 s (`tick`), so « depuis »
/// keeps up while nothing else changes.
final class _HomeCard extends ConsumerStatefulWidget {
  const _HomeCard({required this.round});

  final RoundOn round;

  @override
  ConsumerState<_HomeCard> createState() => _HomeCardState();
}

final class _HomeCardState extends ConsumerState<_HomeCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ref.read(roundProvider.notifier).tick(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final round = widget.round;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: DecoratedBox(
        key: const Key('round.card'),
        decoration: BoxDecoration(
          border: Border.all(color: colors.ink, width: AppSizes.borderWidth),
          borderRadius: BorderRadius.circular(AppSizes.roundCardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              _SeeDons(
                key: const Key('round.card.dons'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        const _RoundDot(),
                        Flexible(
                          child: Text(
                            roundSinceText(l10n, round.elapsed),
                            key: const Key('round.card.since'),
                            style: AppTextStyles.rowCount.copyWith(
                              color: colors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      roundTotalsText(l10n, round.totals),
                      key: const Key('round.card.totals'),
                      style: AppTextStyles.roundTotals.copyWith(
                        color: colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              _FinishButton(
                onPressed: () => unawaited(context.push(AppRoutes.roundRecap)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « ■ Terminer », filled in ink: the end of the outing, set apart from the
/// red of the app's main actions. Screen readers hear « Terminer la
/// tournée ».
final class _FinishButton extends StatelessWidget {
  const _FinishButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: l10n.roundFinishSpoken,
      excludeSemantics: true,
      child: FilledButton.icon(
        key: const Key('round.finish'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.ink,
          foregroundColor: colors.surface,
          minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
          textStyle: AppTextStyles.rowCount,
        ),
        icon: const Icon(Icons.stop, size: AppSizes.smallIcon),
        label: Text(l10n.roundFinish),
      ),
    );
  }
}

/// The street screen's line under its progress bar while a tournée is on
/// (RunStreet): « ● En tournée · 19 dons · 280 € » and « Voir les dons › »;
/// a tap calls [onOpenDons]. Nothing while none is on.
final class RoundStreetLine extends ConsumerWidget {
  const RoundStreetLine({super.key, required this.onOpenDons});

  final VoidCallback onOpenDons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final round = ref.watch(roundProvider);
    if (round is! RoundOn) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.gutter,
        12,
        AppSizes.gutter,
        0,
      ),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.ink, width: AppSizes.borderWidth),
          borderRadius: BorderRadius.circular(AppSizes.roundLineRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: _SeeDons(
          key: const Key('round.line'),
          onTap: onOpenDons,
          minHeight: AppSizes.roundLineHeight,
          padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
          child: Row(
            spacing: 8,
            children: [
              const _RoundDot(),
              Flexible(
                child: Text(
                  l10n.roundStreetLine(roundTotalsText(l10n, round.totals)),
                  key: const Key('round.line.totals'),
                  style: AppTextStyles.rowCount.copyWith(color: colors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [child], then « Voir les dons › » at the end of the row: a button that
/// opens « Dons de la tournée » ([onTap], by default a push), at least
/// 48 dp high. Screen readers hear its words and « Voir les dons ».
final class _SeeDons extends StatelessWidget {
  const _SeeDons({
    super.key,
    required this.child,
    this.onTap,
    this.minHeight = AppSizes.minTapTarget,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double minHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: onTap ?? () => unawaited(context.push(AppRoutes.roundDons)),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: padding,
            child: Row(
              spacing: 8,
              children: [
                Expanded(child: child),
                Text(
                  l10n.roundSeeDons,
                  semanticsLabel: l10n.roundSeeDonsSpoken,
                  style: AppTextStyles.small.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The red ● of « En tournée »: decoration, the words say it.
final class _RoundDot extends StatelessWidget {
  const _RoundDot();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: AppSizes.roundDot,
      height: AppSizes.roundDot,
      decoration: BoxDecoration(
        color: AppColors.of(context).accent,
        shape: BoxShape.circle,
      ),
    ),
  );
}
