import 'package:flutter/material.dart';
import 'package:tournee_calendriers/presentation/street_part/other_sectors.dart';
import 'package:tournee_calendriers/ui/components/street_part_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Under a street to add that other secteurs hold in part, one line each:
/// « Secteur 12 : impairs 19–41 » (PLAN §5.15, « When adding »), so the
/// part can be chosen before adding. Shared by the selection sheet, the
/// zone's list and « Liste ». Nothing when [lines] is empty.
final class OtherSectorLines extends StatelessWidget {
  const OtherSectorLines({super.key, required this.lines});

  final List<OtherSectorLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final style = AppTextStyles.small.copyWith(
      color: AppColors.of(context).ink,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          Text(otherSectorText(l10n, line), style: style),
      ],
    );
  }
}
