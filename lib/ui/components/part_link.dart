import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/ui/components/open_chevron.dart';
import 'package:tournee_calendriers/ui/components/street_part_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The red link under a street to add, naming its part (« Toute la rue › »,
/// « Pairs 2–8 › », Pick mockup, PLAN §5.15): a tap opens « Partie de la
/// rue ». Shared by the rows of the selection sheet, of the zone's list and
/// of « Liste ».
///
/// While the street's numbers are read, a spinner takes the place of › and
/// a tap does nothing. 48 dp high, for the finger, where the mockup draws
/// 32.
final class PartLink extends StatelessWidget {
  const PartLink({
    super.key,
    required this.part,
    required this.reading,
    required this.onTap,
  });

  final StreetPart part;
  final bool reading;

  /// Null while the streets are being added.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = streetPartText(l10n, part);
    final enabled = onTap != null && !reading;
    final color = enabled ? colors.accent : colors.muted;
    // One button for screen readers: « Partie de la rue : Pairs 2–8 ».
    // `container`: a node of its own, not merged with the street's name
    // and count above it, which are no button.
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: l10n.streetPartRowSemantics(text),
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Flexible(
                child: Text(
                  text,
                  style: AppTextStyles.small.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (reading)
                SizedBox.square(
                  dimension: AppSizes.partLinkChevron,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.muted,
                  ),
                )
              else
                OpenChevron(height: AppSizes.partLinkChevron, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
