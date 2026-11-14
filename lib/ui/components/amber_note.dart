import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « ⚠ … » in a pale amber box with an amber edge (`.flag` and `.info` of
/// the mockups, PLAN §5.20): something to know, not an error (« La liste
/// des dons ne correspond plus aux totaux. », « Touchez la maison
/// oubliée… »). The ⚠ and the words say it, never the colour alone.
final class AmberNote extends StatelessWidget {
  const AmberNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = AppTextStyles.body.copyWith(color: colors.ink, height: 1.35);
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.nobodyHomePale,
          border: Border.all(
            color: colors.nobodyHomeBorder,
            width: AppSizes.amberNoteBorder,
          ),
          borderRadius: BorderRadius.circular(AppSizes.tileRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              ExcludeSemantics(
                child: Text(
                  '⚠',
                  style: style.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(child: Text(text, style: style)),
            ],
          ),
        ),
      ),
    );
  }
}
