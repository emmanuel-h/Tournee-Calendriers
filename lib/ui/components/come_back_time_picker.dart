import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/shared/calendar_day.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Quand repasser ? » (PLAN §5.7, `docs/mockups/HouseComeBack.dc.html`,
/// #81, #82): the day chips « Aujourd'hui » and « Demain », then a round 📅
/// button opening the calendar for any other day, the hour list (« Pas
/// d'heure », 8 h to 21 h) and the line that says it in words (« Le samedi
/// 24 oct. vers 18 h »).
///
/// Each choice is handed at once to [onDay] or [onHour], which store it:
/// there is nothing to save when the sheet closes. Tapping the chosen chip
/// again unchooses its day (no time set). The hour list waits for a day.
///
/// Drawn in the blue of « Repasser » while [enabled]; greyed, nothing to
/// tap, otherwise (a house that is not « Repasser » any more). The block
/// around it belongs to the sheet; the label « Quand repasser ? » heads it
/// unless the sheet's title already says it ([titled] false: the status
/// picker's « N° 5 · quand repasser ? »).
final class ComeBackTimePicker extends StatelessWidget {
  const ComeBackTimePicker({
    super.key,
    required this.name,
    required this.time,
    required this.enabled,
    required this.onDay,
    required this.onHour,
    this.titled = true,
  });

  /// Names the parts for tests: `<name>.comeBackDay.2026-10-24` (a chip),
  /// `<name>.comeBackOtherDay` (📅), `<name>.comeBackHour`,
  /// `<name>.comeBackSummary`.
  final String name;

  final ComeBackTime time;
  final bool enabled;
  final ValueChanged<CalendarDay?> onDay;
  final ValueChanged<int?> onHour;

  /// Starts with the label « Quand repasser ? ».
  final bool titled;

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
        if (titled)
          Text(
            l10n.comeBackWhenLabel,
            style: AppTextStyles.fieldLabel.copyWith(color: ink),
          ),
        Semantics(
          label: l10n.comeBackDayGroup,
          container: true,
          explicitChildNodes: true,
          // Scrolls sideways only when a large phone font makes the row
          // wider than the sheet.
          child: SingleChildScrollView(
            key: ValueKey('$name.comeBackDays'),
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: [
                for (final (day, label) in [
                  (time.today, l10n.comeBackToday),
                  (time.tomorrow, l10n.comeBackTomorrow),
                ])
                  _DayChip(
                    key: ValueKey('$name.comeBackDay.$day'),
                    label: label,
                    chosen: day == chosen?.day,
                    onTap: enabled
                        ? () => onDay(day == chosen?.day ? null : day)
                        : null,
                  ),
                _OtherDayButton(
                  key: ValueKey('$name.comeBackOtherDay'),
                  otherDay: time.otherDay,
                  onTap: enabled ? () => _pickDay(context) : null,
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

  /// Opens Material's calendar, in French since the app's locale is, from
  /// today to [ComeBackTime.calendarDays] ahead, and stores the day picked
  /// with « OK » as a chip would; « Annuler » (null) changes nothing.
  Future<void> _pickDay(BuildContext context) async {
    final colors = AppColors.of(context);
    final picked = await showDatePicker(
      context: context,
      firstDate: time.today.toDateTime(),
      lastDate: time.lastCalendarDay.toDateTime(),
      initialDate: time.calendarStart.toDateTime(),
      // Today from the app's clock (the `Clock` port behind [time]), not
      // from `DateTime.now()`, so the ring around today matches the chip.
      currentDate: time.today.toDateTime(),
      // The dialog reads its colours from the theme above it: the
      // come-back blue for the chosen day and the buttons, as the chips.
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme
              .copyWith(primary: colors.onComeBack, onPrimary: colors.surface),
        ),
        child: child!,
      ),
    );
    if (picked != null) onDay(CalendarDay.of(picked));
  }
}

/// The line under « Quand repasser ? »: « Le samedi 24 oct. vers 18 h »,
/// « Aujourd'hui », « Demain vers 9 h », « C'était hier vers 18 h » for a
/// time gone, « Aucun jour sélectionné » before a day is chosen.
String comeBackSummaryText(AppLocalizations l10n, ComeBackTime time) =>
    switch (time.chosen) {
      final chosen? => comeBackWhenText(l10n, chosen, time.hour),
      null => l10n.comeBackNoDay,
    };

/// When to come back on [day], at about [hour] when given, as the sheet
/// and « À repasser » say it (PLAN §5.7, §5.17): « Aujourd'hui vers 19 h »,
/// « Le samedi 24 oct. », « C'était hier vers 18 h ».
String comeBackWhenText(AppLocalizations l10n, ComeBackDay day, int? hour) {
  final date = day.day.toDateTime();
  return switch ((day.fromToday, hour)) {
    (DayFromToday.earlier, null) => l10n.comeBackPastDay(date),
    (DayFromToday.earlier, final hour?) => l10n.comeBackPastDayAt(date, hour),
    (DayFromToday.yesterday, null) => l10n.comeBackOnYesterday,
    (DayFromToday.yesterday, final hour?) => l10n.comeBackOnYesterdayAt(hour),
    (DayFromToday.today, null) => l10n.comeBackOnToday,
    (DayFromToday.today, final hour?) => l10n.comeBackOnTodayAt(hour),
    (DayFromToday.tomorrow, null) => l10n.comeBackOnTomorrow,
    (DayFromToday.tomorrow, final hour?) => l10n.comeBackOnTomorrowAt(hour),
    (DayFromToday.later, null) => l10n.comeBackOnDay(date),
    (DayFromToday.later, final hour?) => l10n.comeBackOnDayAt(date, hour),
  };
}

/// « Aujourd'hui » or « Demain », a radio of the row « Jour ».
final class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.label,
    required this.chosen,
    required this.onTap,
  });

  final String label;
  final bool chosen;

  /// Null while the block is greyed.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _DayPill(
    label: label,
    chosen: chosen,
    onTap: onTap,
    // The chip is drawn 40 dp high as in the mockup; the 4 dp above and
    // below still answer taps, for a 48 dp target.
    padding: const EdgeInsets.symmetric(vertical: _pillMargin),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        label,
        style: AppTextStyles.pill.copyWith(
          color: _DayPill.inkOf(context, onTap, chosen),
        ),
      ),
    ),
  );
}

/// The round 📅 after the chips: opens the calendar. Filled, and naming the
/// day (« Autre jour, dimanche 15 novembre »), when [otherDay] is chosen.
final class _OtherDayButton extends StatelessWidget {
  const _OtherDayButton({
    super.key,
    required this.otherDay,
    required this.onTap,
  });

  /// The chosen day no chip shows; null when there is none.
  final ComeBackDay? otherDay;

  /// Null while the block is greyed.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final otherDay = this.otherDay;
    final chosen = otherDay != null;
    return _DayPill(
      label: chosen
          ? l10n.comeBackOtherDaySemantics(otherDay.day.toDateTime())
          : l10n.comeBackOtherDay,
      chosen: chosen,
      onTap: onTap,
      // A 40 dp circle with 4 dp all round: a 48 dp square target.
      padding: const EdgeInsets.all(_pillMargin),
      width: AppSizes.pillHeight,
      child: Icon(
        Icons.calendar_today,
        size: AppSizes.smallIcon,
        color: _DayPill.inkOf(context, onTap, chosen),
      ),
    );
  }
}

/// What the 40 dp pill leaves of the 48 dp target on each side.
const _pillMargin = (AppSizes.minTapTarget - AppSizes.pillHeight) / 2;

/// A pill of the row « Jour »: white outlined in blue, filled blue when
/// [chosen], grey when there is nothing to tap.
final class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.label,
    required this.chosen,
    required this.onTap,
    required this.padding,
    required this.child,
    this.width,
  });

  /// What a screen reader says for it.
  final String label;
  final bool chosen;
  final VoidCallback? onTap;

  /// Around the pill, inside the tap target.
  final EdgeInsets padding;
  final Widget child;

  /// Null: as wide as [child].
  final double? width;

  /// The colour of the text or icon on the pill.
  static Color inkOf(BuildContext context, VoidCallback? onTap, bool chosen) {
    final colors = AppColors.of(context);
    return switch ((onTap != null, chosen)) {
      (true, true) => colors.surface,
      (true, false) => colors.onComeBack,
      (false, _) => colors.muted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (background, border) = switch ((onTap != null, chosen)) {
      (true, true) => (colors.onComeBack, colors.onComeBack),
      (true, false) => (colors.surface, colors.comeBackBorder),
      // Greyed: no « repasser », hence no day chosen.
      (false, _) => (colors.surface, colors.line),
    };
    // `checked` in a mutually exclusive group: TalkBack says « case
    // d'option, cochée », like a radio button.
    return Semantics(
      label: label,
      checked: chosen,
      inMutuallyExclusiveGroup: true,
      enabled: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: padding,
          child: Container(
            height: AppSizes.pillHeight,
            width: width,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: border, width: AppSizes.borderWidth),
              borderRadius: BorderRadius.circular(AppSizes.pillHeight / 2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
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
