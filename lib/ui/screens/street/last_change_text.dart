import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// « Modifié par Léa · 14:02 » (today) or « Modifié par Léa · 3 oct. à
/// 14:02 » (before), « par vous » for the member on the phone, and without
/// a name when nobody is known (« Modifié à 14:02 »), in the phone's time
/// zone (PLAN §5.7). The dates are written by `intl` from the French rules
/// (`app_fr.arb`); the notifier decided which case it is.
String lastChangeText(AppLocalizations l10n, LastChange change) {
  final name = switch (change.by) {
    ChangedByMe() => l10n.houseChangedByMe,
    ChangedByMember(:final name) => name,
    null => null,
  };
  return switch ((change, name)) {
    (ChangedToday(:final at), null) => l10n.houseChangedToday(at),
    (ChangedEarlier(:final at), null) => l10n.houseChangedOn(at, at),
    (ChangedToday(:final at), final String name) => l10n.houseChangedByToday(
      name,
      at,
    ),
    (ChangedEarlier(:final at), final String name) => l10n.houseChangedByOn(
      name,
      at,
      at,
    ),
  };
}
