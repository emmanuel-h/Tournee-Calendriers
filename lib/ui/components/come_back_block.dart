import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// The blue block of a house or door sheet: « ☑ ↻ Repasser » and, once
/// ticked, when to come back ([hint]). When not [enabled] (the house or
/// door is done) the box is greyed and says why.
final class ComeBackBlock extends StatelessWidget {
  const ComeBackBlock({
    super.key,
    required this.name,
    required this.ticked,
    required this.enabled,
    required this.onChanged,
    required this.hint,
  });

  /// Names the parts for tests: `<name>.comeBack`, `<name>.comeBackDisabled`.
  final String name;

  final bool ticked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  /// The hint field, shown while « Repasser » is ticked.
  final Widget hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final foreground = enabled ? colors.onComeBack : colors.muted;
    void toggle() => onChanged(!ticked);
    return Container(
      padding: const EdgeInsets.all(AppSizes.comeBackPadding),
      decoration: BoxDecoration(
        color: enabled ? colors.comeBack : colors.ground,
        borderRadius: BorderRadius.circular(AppSizes.segmentRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          // One node for screen readers: « Repasser, case à cocher, non
          // cochée, désactivée, Déjà fait : rien à repasser. »
          MergeSemantics(
            child: InkWell(
              key: ValueKey('$name.comeBack'),
              onTap: enabled ? toggle : null,
              borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The whole row answers taps over at least 48 dp, so the
                  // box itself can keep the mockup's size.
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSizes.minTapTarget,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: ticked,
                          onChanged: enabled ? (_) => toggle() : null,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
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
                          style: AppTextStyles.button.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!enabled)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        l10n.comeBackDoneReason,
                        key: ValueKey('$name.comeBackDisabled'),
                        style: AppTextStyles.small.copyWith(
                          color: colors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (ticked) hint,
        ],
      ),
    );
  }
}
