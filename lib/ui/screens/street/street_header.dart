import 'package:flutter/material.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// Everything above the tiles: « 31/42 · ✗ 3 · ↻ 1 » with « Masquer
/// faits », the progress bar, and the « Côté impair | Côté pair » labels.
final class StreetHeader extends StatelessWidget {
  const StreetHeader({
    super.key,
    required this.state,
    required this.onToggleHideDone,
  });

  final StreetShown state;
  final VoidCallback onToggleHideDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSizes.streetCountsIndent,
            right: AppSizes.gutter,
          ),
          child: SizedBox(
            height: AppSizes.streetCountsHeight,
            child: Row(
              children: [
                Expanded(child: _Counts(state: state)),
                _HideDoneToggle(
                  hideDone: state.hideDone,
                  onPressed: onToggleHideDone,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.progressBarHeight / 2),
            child: LinearProgressIndicator(
              key: const Key('street.progress'),
              value: state.fraction,
              minHeight: AppSizes.progressBarHeight,
              // The counts above already say it to screen readers.
              semanticsLabel: '',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            14,
            AppSizes.gutter,
            6,
          ),
          child: Row(
            spacing: AppSizes.columnGap,
            children: [
              if (state.columns != StreetColumns.evenOnly)
                Expanded(
                  child: SectionHeader(l10n.oddSide, padding: EdgeInsets.zero),
                ),
              if (state.columns != StreetColumns.oddOnly)
                Expanded(
                  child: SectionHeader(l10n.evenSide, padding: EdgeInsets.zero),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// « 31/42 · ✗ 3 · ↻ 1 », with the glyphs drawn (the fonts lack ↻), and one
/// French sentence for screen readers.
final class _Counts extends StatelessWidget {
  const _Counts({required this.state});

  final StreetShown state;

  static const _glyphSize = 15.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = AppColors.of(context).muted;
    // A `WidgetSpan` puts a widget inside a line of text; `middle` centres
    // it on the line rather than sitting it on the baseline.
    WidgetSpan glyph(StatusGlyphs which) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: StatusGlyph(which, size: _glyphSize, color: muted),
    );
    return Semantics(
      label: l10n.streetCountsSemantics(
        state.done,
        state.total,
        state.nobodyHome,
        state.comeBack,
      ),
      excludeSemantics: true,
      child: Text.rich(
        key: const Key('street.counts'),
        TextSpan(
          children: [
            TextSpan(
              text: '${l10n.streetProgress(state.done, state.total)} · ',
            ),
            glyph(StatusGlyphs.nobodyHome),
            TextSpan(text: ' ${state.nobodyHome} · '),
            glyph(StatusGlyphs.comeBack),
            TextSpan(text: ' ${state.comeBack}'),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.streetCounts.copyWith(color: muted),
      ),
    );
  }
}

/// The « ☐ Masquer faits » pill: white with an outline when off, ink with
/// white text and a ticked box when on.
final class _HideDoneToggle extends StatelessWidget {
  const _HideDoneToggle({required this.hideDone, required this.onPressed});

  final bool hideDone;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final background = hideDone ? colors.ink : colors.surface;
    final foreground = hideDone ? colors.surface : colors.ink;
    // `toggled` makes TalkBack say « activé » / « désactivé » after the
    // label: the box glyph alone would not be read. `MergeSemantics` makes
    // the flag and the button one node, read at once.
    return MergeSemantics(
      key: const Key('street.hideDone'),
      child: Semantics(
        toggled: hideDone,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(
            hideDone ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
          ),
          label: Text(AppLocalizations.of(context).hideDone),
          style: ButtonStyle(
            // 40 dp drawn; the button still answers taps over 48 dp.
            minimumSize: const WidgetStatePropertyAll(
              Size(0, AppSizes.pillHeight),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 14),
            ),
            textStyle: const WidgetStatePropertyAll(AppTextStyles.pill),
            backgroundColor: WidgetStatePropertyAll(background),
            foregroundColor: WidgetStatePropertyAll(foreground),
            iconColor: WidgetStatePropertyAll(foreground),
            side: WidgetStatePropertyAll(
              BorderSide(
                color: hideDone ? colors.ink : colors.line,
                width: AppSizes.borderWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
