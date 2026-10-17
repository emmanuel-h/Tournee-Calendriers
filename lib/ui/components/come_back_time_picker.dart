import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/shared/calendar_day.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Quand repasser ? » (PLAN §5.7, `docs/mockups/HouseComeBack.dc.html`,
/// #81): a row of day chips scrolling sideways (« Aujourd'hui », « Demain »,
/// « Sam. 24 »…), the hour list (« Pas d'heure », 8 h to 21 h) and the line
/// that says it in words (« Le samedi 24 oct. vers 18 h »).
///
/// Each choice is handed at once to [onDay] or [onHour], which store it:
/// there is nothing to save when the sheet closes. Tapping the chosen day
/// again unchooses it (no time set). The hour list waits for a day.
///
/// Drawn in the blue of « Repasser » while [enabled]; greyed, nothing to
/// tap, otherwise (a house that is not « Repasser »). The block around it
/// belongs to the sheet.
final class ComeBackTimePicker extends StatelessWidget {
  const ComeBackTimePicker({
    super.key,
    required this.name,
    required this.time,
    required this.enabled,
    required this.onDay,
    required this.onHour,
  });

  /// Names the parts for tests: `<name>.comeBackDay.2026-10-24`,
  /// `<name>.comeBackHour`, `<name>.comeBackSummary`.
  final String name;

  final ComeBackTime time;
  final bool enabled;
  final ValueChanged<CalendarDay?> onDay;
  final ValueChanged<int?> onHour;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final ink = enabled ? colors.onComeBack : colors.muted;
    final chosen = time.chosen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(
          l10n.comeBackWhenLabel,
          style: AppTextStyles.fieldLabel.copyWith(color: ink),
        ),
        Semantics(
          label: l10n.comeBackDayGroup,
          container: true,
          explicitChildNodes: true,
          child: SingleChildScrollView(
            key: ValueKey('$name.comeBackDays'),
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: [
                for (final day in time.days)
                  _DayChip(
                    key: ValueKey('$name.comeBackDay.${day.day}'),
                    day: day,
                    chosen: day == chosen,
                    onTap: enabled
                        ? () => onDay(day == chosen ? null : day.day)
                        : null,
                  ),
              ],
            ),
          ),
        ),
        Row(
          spacing: 12,
          children: [
            Text(
              l10n.comeBackHourLabel,
              style: AppTextStyles.fieldLabel.copyWith(color: ink),
            ),
            Expanded(
              child: _HourList(
                key: ValueKey('$name.comeBackHour'),
                time: time,
                // An hour needs a day.
                onHour: enabled && chosen != null ? onHour : null,
              ),
            ),
          ],
        ),
        Text(
          comeBackSummaryText(l10n, time),
          key: ValueKey('$name.comeBackSummary'),
          style: AppTextStyles.fieldLabel.copyWith(color: ink),
        ),
      ],
    );
  }
}

/// The line under « Quand repasser ? »: « Le samedi 24 oct. vers 18 h »,
/// « Aujourd'hui », « Demain vers 9 h », « C'était hier vers 18 h » for a
/// time gone, « Pas de jour choisi » before a day is chosen.
String comeBackSummaryText(AppLocalizations l10n, ComeBackTime time) {
  final chosen = time.chosen;
  if (chosen == null) return l10n.comeBackNoDay;
  final day = chosen.day.toDateTime();
  return switch ((chosen.fromToday, time.hour)) {
    (DayFromToday.earlier, null) => l10n.comeBackPastDay(day),
    (DayFromToday.earlier, final hour?) => l10n.comeBackPastDayAt(day, hour),
    (DayFromToday.yesterday, null) => l10n.comeBackOnYesterday,
    (DayFromToday.yesterday, final hour?) => l10n.comeBackOnYesterdayAt(hour),
    (DayFromToday.today, null) => l10n.comeBackOnToday,
    (DayFromToday.today, final hour?) => l10n.comeBackOnTodayAt(hour),
    (DayFromToday.tomorrow, null) => l10n.comeBackOnTomorrow,
    (DayFromToday.tomorrow, final hour?) => l10n.comeBackOnTomorrowAt(hour),
    (DayFromToday.later, null) => l10n.comeBackOnDay(day),
    (DayFromToday.later, final hour?) => l10n.comeBackOnDayAt(day, hour),
  };
}

/// One day of the row: « Aujourd'hui », « Demain », « Hier », or the short
/// weekday and date (« Sam. 24 »), which screen readers hear whole
/// (« samedi 24 octobre »).
final class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.day,
    required this.chosen,
    required this.onTap,
  });

  final ComeBackDay day;
  final bool chosen;

  /// Null while the block is greyed.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final on = onTap != null;
    final date = day.day.toDateTime();
    final (label, spoken) = switch (day.fromToday) {
      DayFromToday.today => (l10n.comeBackToday, null),
      DayFromToday.tomorrow => (l10n.comeBackTomorrow, null),
      DayFromToday.yesterday => (l10n.comeBackYesterday, null),
      DayFromToday.earlier || DayFromToday.later => (
        _capitalized(l10n.comeBackChipDay(date)),
        l10n.comeBackChipDaySemantics(date),
      ),
    };
    final (background, border, text) = switch ((on, chosen)) {
      (true, true) => (colors.onComeBack, colors.onComeBack, colors.surface),
      (true, false) => (
        colors.surface,
        colors.comeBackBorder,
        colors.onComeBack,
      ),
      // Greyed: no « repasser », hence no day chosen.
      (false, _) => (colors.surface, colors.line, colors.muted),
    };
    // `checked` in a mutually exclusive group: TalkBack says « case
    // d'option, cochée », like a radio button.
    return Semantics(
      label: spoken ?? label,
      checked: chosen,
      inMutuallyExclusiveGroup: true,
      enabled: on,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        // The chip is drawn 40 dp high as in the mockup; the 4 dp above and
        // below still answer taps, for a 48 dp target.
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: (AppSizes.minTapTarget - AppSizes.pillHeight) / 2,
          ),
          child: Container(
            height: AppSizes.pillHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: border, width: AppSizes.borderWidth),
              borderRadius: BorderRadius.circular(AppSizes.pillHeight / 2),
            ),
            child: Text(label, style: AppTextStyles.pill.copyWith(color: text)),
          ),
        ),
      ),
    );
  }

  /// « sam. 24 » as the mockup writes it: « Sam. 24 ».
  static String _capitalized(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// « Pas d'heure », then 8 h to 21 h. Null [onHour] greys it out.
final class _HourList extends StatelessWidget {
  const _HourList({super.key, required this.time, required this.onHour});

  final ComeBackTime time;
  final ValueChanged<int?>? onHour;

  /// The item of « Pas d'heure »: the list needs a value for each item,
  /// and an hour of 0 is never offered.
  static const _noHour = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final onHour = this.onHour;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
      borderSide: BorderSide(
        color: onHour == null ? colors.line : colors.comeBackBorder,
        width: AppSizes.borderWidth,
      ),
    );
    return DropdownButtonFormField<int>(
      // The list shows the stored hour, which a teammate may change: a new
      // key builds it again with that value, since `initialValue` is only
      // read once.
      key: ValueKey(time.hour),
      initialValue: time.hour ?? _noHour,
      isExpanded: true,
      style: AppTextStyles.bodyLarge.copyWith(color: colors.ink),
      decoration: InputDecoration(
        enabledBorder: border,
        disabledBorder: border,
        border: border,
      ),
      items: [
        DropdownMenuItem(value: _noHour, child: Text(l10n.comeBackNoHour)),
        for (final hour in time.hours)
          DropdownMenuItem(value: hour, child: Text(l10n.comeBackHour(hour))),
      ],
      onChanged: onHour == null
          ? null
          : (value) => onHour(value == _noHour ? null : value),
    );
  }
}
