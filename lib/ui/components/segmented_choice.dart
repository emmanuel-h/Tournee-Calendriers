import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// One option of a [SegmentedChoice].
final class Segment<T> {
  const Segment({
    required this.value,
    required this.label,
    required this.key,
    this.glyph,
    this.semanticsLabel,
  });

  final T value;

  /// What the segment shows (« Fait », « Esc. A · 7/12 »).
  final String label;

  /// Finds the segment in tests (`house.status.done`).
  final Key key;

  /// A status glyph drawn before the label (« ✓ Fait »).
  final StatusGlyphs? glyph;

  /// What screen readers hear instead of [label], when the label is short
  /// hand (« Esc. A · 7/12 » → « Escalier A, 7 sur 12 faits »).
  final String? semanticsLabel;
}

/// A row of options of which one is chosen, the chosen one in ink with
/// white text (« À faire | Fait | Personne », « Esc. A | Esc. B »,
/// « 51, 52… | 5A, 5B… | Libres »).
///
/// Screen readers hear a group named [groupLabel] of radio buttons, each
/// « cochée » or not. Tapping the chosen option does nothing.
final class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.groupLabel,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.height = AppSizes.segmentHeight,
    this.textStyle = AppTextStyles.compactButton,
  });

  final String groupLabel;
  final List<Segment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;

  /// At least [AppSizes.minTapTarget].
  final double height;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final divider = BorderSide(color: colors.line, width: AppSizes.borderWidth);
    return Semantics(
      label: groupLabel,
      container: true,
      explicitChildNodes: true,
      child: Container(
        decoration: BoxDecoration(
          border: Border.fromBorderSide(divider),
          borderRadius: BorderRadius.circular(AppSizes.segmentRadius),
        ),
        // Clips the chosen segment's ink to the rounded corners.
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            for (final (index, segment) in segments.indexed)
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      left: index == 0 ? BorderSide.none : divider,
                    ),
                  ),
                  child: _SegmentButton(
                    segment: segment,
                    selected: segment.value == selected,
                    height: height,
                    textStyle: textStyle,
                    onTap: () => onSelected(segment.value),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.segment,
    required this.selected,
    required this.height,
    required this.textStyle,
    required this.onTap,
  });

  final Segment<T> segment;
  final bool selected;
  final double height;
  final TextStyle textStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = selected ? colors.surface : colors.ink;
    final glyph = segment.glyph;
    // `checked` in a mutually exclusive group: TalkBack says « case
    // d'option, cochée », like a radio button.
    return Semantics(
      key: segment.key,
      label: segment.semanticsLabel ?? segment.label,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      onTap: selected ? null : onTap,
      child: Material(
        color: selected ? colors.ink : colors.surface,
        child: InkWell(
          onTap: selected ? null : onTap,
          child: SizedBox(
            height: height,
            // A large text setting shrinks the label rather than cutting it.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  spacing: 6,
                  children: [
                    if (glyph != null)
                      StatusGlyph(
                        glyph,
                        size: AppSizes.segmentGlyph,
                        color: foreground,
                      ),
                    Text(
                      segment.label,
                      style: textStyle.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
