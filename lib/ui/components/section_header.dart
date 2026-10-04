import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// A small-capitals label above a group (« MEMBRES (5) », « HORS-LIGNE »).
///
/// The label is written normally (« Membres (5) ») and shown in capitals, so
/// screen readers do not spell it out letter by letter.
final class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.label, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 8),
  });

  final String label;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Semantics(
      header: true,
      label: label,
      excludeSemantics: true,
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.sectionHeader.copyWith(
          color: AppColors.of(context).muted,
        ),
      ),
    ),
  );
}
