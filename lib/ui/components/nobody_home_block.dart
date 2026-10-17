import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// The block of a house or door sheet under its status control (#80,
/// `docs/mockups/HouseNobody.dc.html`): « ✗ 2 passages sans personne » and
/// the button « Repassé, toujours personne ».
///
/// Pale yellow, the button enabled, while the house or door is
/// « personne » or « repasser » ([onNobodyHomeAgain] given); greyed, the
/// button disabled, otherwise. Always there, like « Quand repasser ? », so
/// choosing a status never moves the sheet: a block appearing on « ✗ »
/// would push the status control up and bring the button under the
/// finger, where a second quick tap would hit it.
final class NobodyHomeBlock extends StatelessWidget {
  const NobodyHomeBlock({
    super.key,
    required this.name,
    required this.tries,
    required this.onNobodyHomeAgain,
  });

  /// Names the parts for tests: `<name>.tries`, `<name>.nobodyHomeAgain`.
  final String name;

  /// How many times nobody was home.
  final int tries;

  /// Null greys the block out.
  final VoidCallback? onNobodyHomeAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final on = onNobodyHomeAgain != null;
    final ink = on ? colors.ink : colors.muted;
    return Container(
      key: ValueKey('$name.nobodyHomeBlock'),
      padding: const EdgeInsets.all(AppSizes.comeBackPadding),
      decoration: BoxDecoration(
        color: on ? colors.nobodyHomePale : colors.ground,
        borderRadius: BorderRadius.circular(AppSizes.segmentRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          // The glyph is decoration: the words say it.
          Row(
            spacing: AppSizes.glyphGap * 2,
            children: [
              StatusGlyph(
                StatusGlyphs.nobodyHome,
                size: AppSizes.segmentGlyph,
                color: ink,
              ),
              Expanded(
                child: Text(
                  l10n.nobodyHomeTries(tries),
                  key: ValueKey('$name.tries'),
                  style: AppTextStyles.fieldLabel.copyWith(color: ink),
                ),
              ),
            ],
          ),
          SecondaryButton(
            key: ValueKey('$name.nobodyHomeAgain'),
            label: l10n.nobodyHomeAgain,
            compact: true,
            outline: on ? colors.nobodyHomeBorder : null,
            onPressed: onNobodyHomeAgain,
          ),
        ],
      ),
    );
  }
}
