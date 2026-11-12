import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/come_backs/come_backs_notifier.dart';
import 'package:tournee_calendriers/presentation/come_backs/come_backs_view.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/come_backs/come_back_words.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// « À repasser (5) » (PLAN §5.17, ComeBackList mockup): every « repasser »
/// of the secteur by day, « Aujourd'hui », « Demain », the later days, then
/// « À tout moment » (no day, or a day gone). A 🔔 on those this phone will
/// ring for. A tap opens the street at the house, or the building's grid
/// at the door. Works offline.
final class ComeBacksScreen extends ConsumerWidget {
  const ComeBacksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final view = ref.watch(comeBacksProvider);
    final note = AppTextStyles.small.copyWith(color: colors.muted, height: 1.4);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Text(l10n.comeBacksTitle(view.count)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const Key('comeBacks.list'),
          children: [
            if (view.anyRings)
              Padding(
                key: const Key('comeBacks.legend'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Row(
                  spacing: 6,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: AppSizes.comeBackBell,
                      color: colors.onComeBack,
                    ),
                    Expanded(
                      child: Text(l10n.comeBacksRingLegend, style: note),
                    ),
                  ],
                ),
              ),
            for (final section in view.sections) ...[
              SectionHeader(_headingText(l10n, section.heading)),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.divider)),
                ),
                child: Column(
                  children: [
                    for (final row in section.rows)
                      _ComeBackTile(
                        key: ValueKey(
                          'comeBacks.row.${AppRoutes.streetAt(row.place)}',
                        ),
                        row: row,
                        onTap: () => context.push(
                          AppRoutes.streetAt(row.place),
                          extra: row.streetName,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (!view.loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Text(
                  view.shown ? l10n.comeBacksFooter : l10n.comeBacksNone,
                  key: const Key('comeBacks.footer'),
                  style: note,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _headingText(AppLocalizations l10n, ComeBackHeading heading) =>
      switch (heading) {
        ComeBackAnyTime() => l10n.comeBacksAnyTime,
        ComeBackOnDay(:final day) => switch (day.fromToday) {
          DayFromToday.today => l10n.comeBackToday,
          DayFromToday.tomorrow => l10n.comeBackTomorrow,
          // A day gone is « À tout moment »: never a heading of its own.
          DayFromToday.later ||
          DayFromToday.yesterday ||
          DayFromToday.earlier => l10n.comeBacksDay(day.day.toDateTime()),
        },
      };
}

/// « [19 h] 12 Rue Nationale · par vous 🔔 › »: the come-back-blue square
/// with the hour (↻ without one, or with a day gone), the address, who
/// set it, the 🔔 when this phone rings for it, and a chevron.
final class _ComeBackTile extends StatelessWidget {
  const _ComeBackTile({super.key, required this.row, required this.onTap});

  final ComeBackRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final details = comeBackRowDetails(l10n, row);
    final hour = row.isPast ? null : row.hour;
    return Semantics(
      button: true,
      label: comeBackRowSemantics(l10n, row),
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.streetRowHeight,
            ),
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              spacing: 12,
              children: [
                Container(
                  width: AppSizes.comeBackSquareWidth,
                  height: AppSizes.comeBackSquareHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.comeBack,
                    borderRadius: BorderRadius.circular(
                      AppSizes.comeBackSquareRadius,
                    ),
                  ),
                  child: switch (hour) {
                    final hour? => Text(
                      l10n.comeBackHour(hour),
                      maxLines: 1,
                      style: AppTextStyles.comeBackHour.copyWith(
                        color: colors.onComeBack,
                      ),
                    ),
                    null => StatusGlyph(
                      StatusGlyphs.comeBack,
                      size: AppSizes.tileGlyph,
                      color: colors.onComeBack,
                    ),
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 2,
                    children: [
                      Text(
                        comeBackRowAddress(l10n, row),
                        style: AppTextStyles.streetName.copyWith(
                          color: colors.ink,
                        ),
                      ),
                      if (details != null)
                        Text(
                          details,
                          style: AppTextStyles.small.copyWith(
                            color: colors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (row.rings)
                  Icon(
                    Icons.notifications_none,
                    key: const Key('comeBacks.bell'),
                    size: AppSizes.comeBackBell,
                    color: colors.onComeBack,
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
      ),
    );
  }
}
