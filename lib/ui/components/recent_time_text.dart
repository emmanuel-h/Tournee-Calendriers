import 'package:tournee_calendriers/presentation/shared/recent_time.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// « à l'instant », « il y a 2 min », « il y a 3 h », « hier » or « 3 oct. »:
/// how long ago, in French. The notifier decided which case it is; dates
/// are written by `intl` from the French rules (`app_fr.arb`).
String recentTimeText(AppLocalizations l10n, RecentTime time) => switch (time) {
  JustNow() => l10n.recentJustNow,
  MinutesAgo(:final minutes) => l10n.recentMinutes(minutes),
  HoursAgo(:final hours) => l10n.recentHours(hours),
  Yesterday() => l10n.recentYesterday,
  OnDay(:final at) => l10n.recentDay(at),
};
