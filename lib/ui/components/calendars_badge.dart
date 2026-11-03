import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// [child] (a house tile or a door of the grid) with, when [calendars] is
/// given, the round ink badge of its calendars at its top right corner
/// (« 2 », PLAN §5.6, #114), half out of it as in the Main and RunStreet
/// mockups.
///
/// The badge is hidden from screen readers: the tile's label says
/// « 2 calendriers » ([spokenWithCalendars]).
final class WithCalendarsBadge extends StatelessWidget {
  const WithCalendarsBadge({
    super.key,
    required this.calendars,
    required this.child,
  });

  /// The count shown, from two; null shows no badge.
  final int? calendars;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final calendars = this.calendars;
    if (calendars == null) return child;
    // `Clip.none`: the badge is drawn past the tile's edge, into the gap
    // around it. `passthrough` gives the tile the size it was given, as
    // without the badge.
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned(
          top: -AppSizes.calendarBadgeOverhang,
          right: -AppSizes.calendarBadgeOverhang,
          child: ExcludeSemantics(child: _Badge(calendars)),
        ),
      ],
    );
  }
}

/// The round badge itself: the number in the ground colour on ink, ringed
/// in the ground colour so it stands off the tile under it.
final class _Badge extends StatelessWidget {
  const _Badge(this.calendars);

  final int calendars;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      key: const Key('tile.calendars'),
      constraints: const BoxConstraints(
        minWidth: AppSizes.calendarBadge,
        minHeight: AppSizes.calendarBadge,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.ink,
        border: Border.all(
          color: colors.ground,
          width: AppSizes.calendarBadgeRing,
        ),
        borderRadius: BorderRadius.circular(AppSizes.calendarBadge / 2),
      ),
      child: Text(
        '$calendars',
        style: AppTextStyles.calendarBadge.copyWith(color: colors.surface),
      ),
    );
  }
}

/// [spoken], the spoken status of a tile or a door, with the calendars of
/// its badge: « fait, 2 calendriers »; [spoken] alone without a badge
/// ([calendars] null).
String spokenWithCalendars(
  AppLocalizations l10n,
  String spoken, {
  required int? calendars,
}) => switch (calendars) {
  null => spoken,
  final count => '$spoken, ${l10n.houseCalendars(count)}',
};
