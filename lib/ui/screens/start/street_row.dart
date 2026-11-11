import 'package:flutter/material.dart';
import 'package:tournee_calendriers/presentation/home/street_row.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// One street of Accueil's list: its name over a progress bar, « 31/403 »
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
    final countColor = row.isComplete ? colors.doneInk : colors.ink;
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

/// A street of Accueil's list whose data cannot be read (PLAN §5.16,
/// StreetUnreadable mockup): a round ⚠ badge, the name over « Illisible »
/// in red (only « Rue illisible » when the name cannot be read either),
/// and a chevron. Never told by the colour alone: the ⚠ and the word say
/// it. Tapping it opens its sheet.
final class UnreadableStreetRowTile extends StatelessWidget {
  const UnreadableStreetRowTile({
    super.key,
    required this.row,
    required this.onTap,
  });

  final UnreadableStreetRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final name = row.name;
    return Semantics(
      button: true,
      label: name == null
          ? l10n.unreadableStreetNoName
          : l10n.unreadableStreetSemantics(name),
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
              Container(
                width: AppSizes.unreadableBadge,
                height: AppSizes.unreadableBadge,
                decoration: BoxDecoration(
                  color: colors.alert,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.accent),
                ),
                // ⚠ drawn as an icon: the text glyph shows as a yellow
                // emoji on Android.
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: AppSizes.doorGlyph,
                  color: colors.accent,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      name ?? l10n.unreadableStreetNoName,
                      style: AppTextStyles.streetName.copyWith(
                        color: colors.ink,
                      ),
                    ),
                    if (name != null)
                      Text(
                        l10n.unreadableStreetLabel,
                        style: AppTextStyles.small.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
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
