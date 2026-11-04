import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/round/round_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The « En tournée » band (PLAN §5.14, mockups RunHome and RunStreet):
/// while this phone's tournée runs in the open secteur, it replaces
/// Accueil's top bar and sits above the street screen's and the building
/// grid's. Nothing while none is on.
///
/// Its left part, « ● En tournée · 1 h 20 » over « 19 dons · 280 € › »,
/// opens « Dons de la tournée »; « ■ Terminer » opens the « Bilan ». Both
/// call [onLeave] first: the street screen and the grid drop their
/// snackbar, whose « Annuler » names a don by its place in the tournée.
///
/// It paints under the status bar, as a top bar does, so its Surface
/// reaches the top of the screen.
final class RoundBand extends ConsumerWidget {
  const RoundBand({super.key, this.onLeave, this.margin = EdgeInsets.zero});

  /// Called before « Dons de la tournée » or the « Bilan » opens.
  final VoidCallback? onLeave;

  /// Room around the band while it shows (none while it does not).
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(roundProvider)) {
        RoundLoading() || RoundOff() => const SizedBox.shrink(),
        final RoundOn round => Padding(
          padding: margin,
          child: _Band(round: round, onLeave: onLeave),
        ),
      };
}

/// A `State`: it reads the clock again every 30 s (`tick`), so « 1 h 20 »
/// keeps up while nothing else changes.
final class _Band extends ConsumerStatefulWidget {
  const _Band({required this.round, required this.onLeave});

  final RoundOn round;
  final VoidCallback? onLeave;

  @override
  ConsumerState<_Band> createState() => _BandState();
}

final class _BandState extends ConsumerState<_Band> {
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

  /// [onLeave], then [location] pushed over the screen.
  void _open(String location) {
    widget.onLeave?.call();
    unawaited(context.push(location));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // The status bar's icons, dark on the light Surface and light on the
    // dark one: an `AnnotatedRegion` at the top of the screen tells
    // Android, as an `AppBar` does for itself.
    final statusBar = colors.brightness == Brightness.light
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBar.copyWith(statusBarColor: Colors.transparent),
      // A `Material`: the ink of a tap shows on the band's own colour.
      child: Material(
        key: const Key('round.band'),
        color: colors.surface,
        child: SafeArea(
          bottom: false,
          child: DecoratedBox(
            key: const Key('round.band.edge'),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: colors.accent,
                  width: AppSizes.roundBandEdge,
                ),
                bottom: BorderSide(color: colors.divider),
              ),
            ),
            child: Padding(
              // A `Border` paints over the child: the left padding starts
              // after the edge.
              padding: const EdgeInsets.fromLTRB(
                AppSizes.roundBandEdge + AppSizes.roundBandIndent,
                12,
                12,
                12,
              ),
              child: Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: _SeeDons(
                      round: widget.round,
                      onTap: () => _open(AppRoutes.roundDons),
                    ),
                  ),
                  _FinishButton(onPressed: () => _open(AppRoutes.roundRecap)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « ● En tournée · 1 h 20 » over « 19 dons · 280 € › »: one button, at
/// least 48 dp high, that opens « Dons de la tournée ». Screen readers hear
/// « En tournée depuis 1 h 20, 19 dons, 280 €. Voir les dons ». The lines
/// wrap with a large phone font.
final class _SeeDons extends StatelessWidget {
  const _SeeDons({required this.round, required this.onTap});

  final RoundOn round;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final elapsed = roundElapsedText(l10n, round.elapsed);
    return Semantics(
      button: true,
      label: l10n.roundBandSpoken(
        elapsed,
        round.totals.count,
        eurosText(l10n, round.totals.cents),
      ),
      // `excludeSemantics` drops the words below, and the tap of the
      // `InkWell` with them: TalkBack's double tap comes in here instead.
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: const Key('round.band.dons'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Row(
                spacing: 8,
                children: [
                  const _RoundDot(),
                  Flexible(
                    child: Text(
                      l10n.roundBandSince(elapsed),
                      key: const Key('round.band.since'),
                      style: AppTextStyles.rowCount.copyWith(color: colors.ink),
                    ),
                  ),
                ],
              ),
              Text(
                l10n.roundBandTotals(roundTotalsText(l10n, round.totals)),
                key: const Key('round.band.totals'),
                style: AppTextStyles.roundTotals.copyWith(color: colors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « ■ Terminer », a 48 dp pill in ink with Surface text (the theme's
/// inverse pair): the end of the outing, set apart from the red of the
/// app's main actions. It never shrinks: with a large phone font the left
/// part wraps instead. Screen readers hear « Terminer la tournée ».
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
      onTap: onPressed,
      child: FilledButton.icon(
        key: const Key('round.finish'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.ink,
          foregroundColor: colors.surface,
          minimumSize: const Size(0, AppSizes.minTapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.roundFinishPadding,
          ),
          shape: const StadiumBorder(),
          textStyle: AppTextStyles.rowCount,
        ),
        icon: const Icon(Icons.stop, size: AppSizes.smallIcon),
        label: Text(l10n.roundFinish),
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
