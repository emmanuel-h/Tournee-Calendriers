import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// The blue block of a building's own sheet (« Repasser »):
/// « ☑ ↻ Repasser » and, once ticked, when to come back ([hint]). A house
/// or a door has no box: « Repasser » is one of its statuses.
final class ComeBackBlock extends StatelessWidget {
  const ComeBackBlock({
    super.key,
    required this.name,
    required this.ticked,
    required this.onChanged,
    required this.hint,
  });

  /// Names the box for tests: `<name>.comeBack`.
  final String name;

  final bool ticked;
  final ValueChanged<bool> onChanged;

  /// The hint field, shown while « Repasser » is ticked.
  final Widget hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final foreground = colors.onComeBack;
    void toggle() => onChanged(!ticked);
    return Container(
      padding: const EdgeInsets.all(AppSizes.comeBackPadding),
      decoration: BoxDecoration(
        color: colors.comeBack,
        borderRadius: BorderRadius.circular(AppSizes.segmentRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          // One node for screen readers: « Repasser, case à cocher, non
          // cochée ».
          MergeSemantics(
            child: InkWell(
              key: ValueKey('$name.comeBack'),
              onTap: toggle,
              borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
              // The whole row answers taps over at least 48 dp, so the box
              // itself can keep the mockup's size.
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTapTarget,
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: ticked,
                      onChanged: (_) => toggle(),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      fillColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? foreground
                            : Colors.transparent,
                      ),
                      checkColor: colors.surface,
                      side: BorderSide(color: foreground, width: 2),
                    ),
                    const SizedBox(width: 8),
                    StatusGlyph(
                      StatusGlyphs.comeBack,
                      size: AppSizes.comeBackGlyph,
                      color: foreground,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.comeBack,
                      style: AppTextStyles.button.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (ticked) hint,
        ],
      ),
    );
  }
}
