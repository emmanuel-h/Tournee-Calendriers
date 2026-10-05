import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

// The view state of « Importer des rues » (PLAN §5.0), made of small
// `sealed` families: the screen `switch`es over each one, and a new case
// breaks the build wherever it must be shown.

/// What went wrong, as the screen tells it. The screen may not name the
/// failures of the application's ports (PLAN §10.1), so the notifier
/// translates them into this.
enum ImportProblem {
  /// The phone could not reach the service: try again with a signal.
  noNetwork,

  /// The service answered with an error or nonsense: try again later.
  serviceError,

  /// The address base does not know the commune or a street.
  notFound;

  static ImportProblem ofDirectory(AddressDirectoryFailure failure) =>
      switch (failure) {
        AddressDirectoryFailure.noNetwork => noNetwork,
        AddressDirectoryFailure.serviceError => serviceError,
        AddressDirectoryFailure.notFound => notFound,
      };

  static ImportProblem ofSearch(CommuneSearchFailure failure) =>
      switch (failure) {
        CommuneSearchFailure.noNetwork => noNetwork,
        CommuneSearchFailure.serviceError => serviceError,
      };
}

/// A commune suggested under the field (« Villefranche-sur-Saône (69400) »).
final class CommuneOption {
  CommuneOption({
    required this.name,
    required this.inseeCode,
    required List<String> postcodes,
  }) : postcodes = List.unmodifiable(postcodes);

  /// The option of a commune the search found.
  factory CommuneOption.of(CommuneMatch match) => CommuneOption(
    name: match.commune.name,
    inseeCode: match.commune.inseeCode,
    postcodes: match.postcodes,
  );

  final String name;

  /// Which commune: the import asks the BAN for it.
  final InseeCode inseeCode;

  /// Five-digit postcodes, possibly none. Read-only.
  final List<String> postcodes;

  @override
  bool operator ==(Object other) =>
      other is CommuneOption &&
      other.name == name &&
      other.inseeCode == inseeCode &&
      sameItems(other.postcodes, postcodes);

  @override
  int get hashCode => Object.hash(name, inseeCode, Object.hashAll(postcodes));

  @override
  String toString() => 'CommuneOption(${inseeCode.value}, $name, $postcodes)';
}

/// What shows under the « Commune » field while typing.
sealed class CommuneSuggestions {
  const CommuneSuggestions();
}

/// Nothing: the field is too short, or a commune was chosen.
final class NoSuggestions extends CommuneSuggestions {
  const NoSuggestions();
}

/// The communes found; empty when none matches (« Aucune commune »).
final class CommunesFound extends CommuneSuggestions {
  CommunesFound(List<CommuneOption> communes)
    : communes = List.unmodifiable(communes);

  final List<CommuneOption> communes;
}

/// The search failed, for [failure].
final class CommuneSearchFailed extends CommuneSuggestions {
  const CommuneSearchFailed(this.failure);

  final ImportProblem failure;
}

/// The streets of the chosen commune, once it is chosen.
sealed class StreetChoices {
  const StreetChoices();
}

/// No commune chosen yet.
final class NoCommuneChosen extends StreetChoices {
  const NoCommuneChosen();
}

/// The BAN is being asked for the commune's streets.
final class LoadingStreets extends StreetChoices {
  const LoadingStreets();
}

/// The streets could not be listed, for [failure]; « Réessayer » asks again.
final class StreetsFailed extends StreetChoices {
  const StreetsFailed(this.failure);

  final ImportProblem failure;
}

/// The commune's streets, in French order of their names.
final class StreetsLoaded extends StreetChoices {
  StreetsLoaded(List<StreetChoice> streets)
    : streets = List.unmodifiable(streets);

  final List<StreetChoice> streets;
}

/// One row of the checklist: « Rue Nationale · 403 n° ».
final class StreetChoice {
  const StreetChoice({
    required this.id,
    required this.name,
    required this.numberCount,
    required this.alreadyImported,
    required this.checked,
    this.inCorbeille = false,
  });

  final BanStreetId id;
  final String name;

  /// How many numbers the BAN lists for it.
  final int numberCount;

  /// In « Mes rues » already: shown ticked and greyed, « déjà importée », and
  /// never imported again (its marks stay).
  final bool alreadyImported;

  /// Imported before and now in the Corbeille: « dans la Corbeille », free
  /// to tick; importing it brings it back with its marks.
  final bool inCorbeille;

  /// Ticked by the user (always true when [alreadyImported]).
  final bool checked;

  /// Whether the user can tick or untick it.
  bool get selectable => !alreadyImported;

  /// Ticked and to be imported by « Importer N rues ».
  bool get toImport => checked && !alreadyImported;

  StreetChoice copyWith({
    bool? checked,
    bool? alreadyImported,
    bool? inCorbeille,
  }) => StreetChoice(
    id: id,
    name: name,
    numberCount: numberCount,
    alreadyImported: alreadyImported ?? this.alreadyImported,
    inCorbeille: inCorbeille ?? this.inCorbeille,
    checked: checked ?? this.checked,
  );

  @override
  bool operator ==(Object other) =>
      other is StreetChoice &&
      other.id == id &&
      other.name == name &&
      other.numberCount == numberCount &&
      other.alreadyImported == alreadyImported &&
      other.inCorbeille == inCorbeille &&
      other.checked == checked;

  @override
  int get hashCode =>
      Object.hash(id, name, numberCount, alreadyImported, inCorbeille, checked);

  @override
  String toString() =>
      'StreetChoice(${id.value}, $name, $numberCount, '
      'alreadyImported: $alreadyImported, inCorbeille: $inCorbeille, '
      'checked: $checked)';
}

/// Where the import itself stands.
sealed class ImportRun {
  const ImportRun();
}

/// « Importer N rues » not pressed yet.
final class ImportNotStarted extends ImportRun {
  const ImportNotStarted();
}

/// Importing: [done] streets out of [total] so far.
final class ImportRunning extends ImportRun {
  const ImportRunning(this.done, this.total);

  final int done;
  final int total;
}

/// Nothing was imported: the commune itself could not be listed.
final class ImportFailed extends ImportRun {
  const ImportFailed(this.failure);

  final ImportProblem failure;
}

/// The import ran; [summary] says how it went.
final class ImportFinished extends ImportRun {
  const ImportFinished(this.summary);

  final ImportSummary summary;
}

/// The counts the screen tells the user after an import.
final class ImportSummary {
  const ImportSummary({
    required this.imported,
    required this.failed,
    this.restored = 0,
    this.failure,
  });

  /// Streets now on the phone from the BAN (those found there meanwhile
  /// included).
  final int imported;

  /// Streets brought back from the Corbeille, with their marks.
  final int restored;

  /// Streets not imported; importing again tries them again.
  final int failed;

  /// Why, when some failed: no network first, as the one the user can act
  /// on; null when none failed.
  final ImportProblem? failure;

  /// Every chosen street is on the phone: the screen goes back to the list.
  bool get complete => failed == 0;
}

/// Everything « Importer des rues » shows. Immutable: each intent of the
/// notifier makes a new one.
final class ImportState {
  const ImportState({
    this.query = '',
    this.searching = false,
    this.suggestions = const NoSuggestions(),
    this.commune,
    this.streets = const NoCommuneChosen(),
    this.filter = '',
    this.run = const ImportNotStarted(),
  });

  /// The text of the « Commune » field.
  final String query;

  /// A search for [query] is on its way: the field shows a spinner.
  final bool searching;
  final CommuneSuggestions suggestions;

  /// The commune chosen among the suggestions; null while searching.
  final CommuneOption? commune;
  final StreetChoices streets;

  /// The text of the « Filtrer les rues… » field.
  final String filter;
  final ImportRun run;

  /// Every street of the commune, filtered or not.
  List<StreetChoice> get _all => switch (streets) {
    StreetsLoaded(:final streets) => streets,
    NoCommuneChosen() || LoadingStreets() || StreetsFailed() => const [],
  };

  /// The rows the filter keeps.
  List<StreetChoice> get visibleStreets => [
    for (final street in _all)
      if (matchesFilter(street.name, filter)) street,
  ];

  /// « 312 rues »: the commune's streets, whatever the filter.
  int get streetCount => _all.length;

  /// The streets « Importer N rues » imports, filtered out or not.
  List<BanStreetId> get toImport => [
    for (final street in _all)
      if (street.toImport) street.id,
  ];

  /// « 1 cochée », and the N of « Importer N rues ».
  int get checkedCount => toImport.length;

  /// Every street the user can tick among the visible ones is ticked (and
  /// there is one): the pill offers « Tout décocher » instead.
  bool get allVisibleChecked {
    final selectable = visibleStreets.where((street) => street.selectable);
    return selectable.isNotEmpty &&
        selectable.every((street) => street.checked);
  }

  bool get importing => run is ImportRunning;

  /// « Importer N rues » can be pressed.
  bool get canImport => checkedCount > 0 && !importing;

  ImportState copyWith({
    String? query,
    bool? searching,
    CommuneSuggestions? suggestions,
    CommuneOption? Function()? commune,
    StreetChoices? streets,
    String? filter,
    ImportRun? run,
  }) => ImportState(
    query: query ?? this.query,
    searching: searching ?? this.searching,
    suggestions: suggestions ?? this.suggestions,
    // A function, so `commune: () => null` can clear it (a plain `null`
    // would mean « unchanged »).
    commune: commune != null ? commune() : this.commune,
    streets: streets ?? this.streets,
    filter: filter ?? this.filter,
    run: run ?? this.run,
  );
}
