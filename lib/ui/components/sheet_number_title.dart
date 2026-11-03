import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The title of a sheet about one number of a street: [big] (« 5 ») large,
/// [beside] it on the same line of writing (« Rue des Lilas »). Screen
/// readers hear one heading. « Modifier le numéro » (edit mode) and the
/// building's own « Repasser » open with it.
final class SheetNumberTitle extends StatelessWidget {
  const SheetNumberTitle({
    super.key,
    required this.name,
    required this.big,
    required this.beside,
  });

  /// The big text is found in tests as `<name>.number`.
  final String name;
  final String big;
  final String beside;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return MergeSemantics(
      child: Semantics(
        header: true,
        child: Row(
          // Both texts sit on one line of writing, as in the mockup.
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: 10,
          children: [
            Text(
              big,
              key: ValueKey('$name.number'),
              style: AppTextStyles.sheetNumber.copyWith(color: colors.ink),
            ),
            Expanded(
              child: Text(
                beside,
                style: AppTextStyles.sheetStreetName.copyWith(
                  color: colors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
