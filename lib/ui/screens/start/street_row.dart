import 'package:flutter/material.dart';
import 'package:tournee_calendriers/presentation/street_list/street_list_notifier.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// One street of « Mes rues »: its name over a progress bar, « 31/403 »
/// (green « ✓ 8/8 » once every door is done) and a chevron. Tapping it
/// opens the street.
final class StreetRowTile extends StatelessWidget {
  const StreetRowTile({super.key, required this.row, required this.onTap});

  final StreetRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final countColor = row.isComplete ? colors.done : colors.ink;
    // One label for the whole row, so a screen reader reads « Rue
    // Nationale, 31 sur 403 faits » once instead of three fragments.
    return Semantics(
      button: true,
      label: row.isComplete
          ? l10n.streetRowCompleteSemantics(row.name, row.total)
          : l10n.streetRowSemantics(row.name, row.done, row.total),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSizes.streetRowHeight,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Text(
                      row.name,
                      style: AppTextStyles.streetName.copyWith(
                        color: colors.ink,
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppSizes.progressBarHeight / 2,
                      ),
                      child: LinearProgressIndicator(
                        value: row.fraction,
                        minHeight: AppSizes.progressBarHeight,
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 64),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: AppSizes.glyphGap,
                  children: [
                    if (row.isComplete)
                      StatusGlyph(
                        StatusGlyphs.done,
                        size: 16,
                        color: countColor,
                      ),
                    Text(
                      l10n.streetProgress(row.done, row.total),
                      style: AppTextStyles.rowCount.copyWith(color: countColor),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: AppSizes.smallIcon,
                color: colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
