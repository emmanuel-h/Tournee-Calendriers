import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// « Modifié à 14:02 » (today) or « Modifié le 3 oct. à 14:02 » (before),
/// in the phone's time zone. The dates are written by `intl` from the
/// French rules (`app_fr.arb`); the notifier decided which case it is.
String lastChangeText(AppLocalizations l10n, LastChange change) =>
    switch (change) {
      ChangedToday(:final at) => l10n.houseChangedToday(at),
      ChangedEarlier(:final at) => l10n.houseChangedOn(at, at),
    };
