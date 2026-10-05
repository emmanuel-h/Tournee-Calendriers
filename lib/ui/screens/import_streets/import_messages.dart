import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

// The French phrasing of each failure of the import screen. A `switch`
// without `default`: a new failure breaks the build here until it is
// phrased.

/// A problem with the address base (the street list, the import).
String addressFailureMessage(AppLocalizations l10n, ImportProblem problem) =>
    switch (problem) {
      ImportProblem.noNetwork => l10n.addressNoNetwork,
      ImportProblem.serviceError => l10n.addressServiceError,
      ImportProblem.notFound => l10n.addressNotFound,
    };

/// A problem with the commune search, which never answers « not found »
/// (it finds nothing instead).
String communeSearchFailureMessage(
  AppLocalizations l10n,
  ImportProblem problem,
) => switch (problem) {
  ImportProblem.noNetwork => l10n.communeSearchNoNetwork,
  ImportProblem.serviceError ||
  ImportProblem.notFound => l10n.communeSearchServiceError,
};

/// « Villefranche-sur-Saône (69400) »: the name and the first postcode,
/// followed by « … » when there are more; the name alone without one.
String communeLabel(AppLocalizations l10n, CommuneOption commune) {
  final name = commune.name;
  return switch (commune.postcodes) {
    [] => name,
    [final postcode] => l10n.communeWithPostcode(name, postcode),
    [final postcode, ...] => l10n.communeWithPostcodes(name, postcode),
  };
}

/// The message after a complete import: « 3 rues importées », « 1 rue
/// restaurée » when only streets from the Corbeille came back, or both.
String importDoneMessage(AppLocalizations l10n, ImportSummary summary) =>
    switch ((summary.imported, summary.restored)) {
      (final imported, 0) => l10n.importDone(imported),
      (0, final restored) => l10n.importRestored(restored),
      (final imported, final restored) => l10n.importDoneAndRestored(
        imported,
        restored,
      ),
    };
