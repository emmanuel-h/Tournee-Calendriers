import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/find_imported_streets.dart';
import 'package:tournee_calendriers/application/use_cases/import_reference_area.dart';
import 'package:tournee_calendriers/application/use_cases/search_communes.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/presentation/add_streets/part_opening.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/street_part/other_sectors.dart';
import 'package:tournee_calendriers/presentation/street_part/street_part_state.dart';

/// How long the « Commune » field waits after the last key before
/// searching, so typing « Villefranche » sends one request, not twelve.
/// A provider so tests can set it to zero.
final communeSearchDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 300),
);

/// The state of the « Liste » tab of « Ajouter des rues ». `autoDispose`:
/// each visit to the screen starts afresh.
final importProvider =
    NotifierProvider.autoDispose<ImportNotifier, ImportState>(
      ImportNotifier.new,
    );

/// The « Liste » tab of « Ajouter des rues » (PLAN §5.4): choose a
/// commune, tick its streets, choose the part of each (PLAN §5.15), add
/// them to the open secteur. Each method is an intent of the screen.
///
/// The commune is one of the secteur's (the first at once, another by its
/// chip), followed live and offline from the phone's copy; a secteur
/// without commune searches one in a field.
///
/// What other secteurs hold of a street ticked is read from the shared
/// index in the background, once per street, and said under its row
/// (« Secteur 12 : impairs 19–41 », PLAN §5.15); nothing when it cannot be
/// read, and nothing waits for it.
final class ImportNotifier extends Notifier<ImportState> {
  /// Raised by each key typed and each commune chosen. A search remembers
  /// the value it started with and gives up when it has changed since:
  /// that is both the debounce (typed again during the delay) and the guard
  /// against stale answers (a slow answer for « Vil » arriving after the
  /// one for « Villef »).
  var _typing = 0;

  /// The same for listing the streets of a commune.
  var _listing = 0;

  /// The numbers read for « Partie de la rue », by street: the part chosen
  /// is counted among them, and opening it again needs no network.
  var _numbers = <BanStreetId, StreetNumbers>{};

  /// What the index said of each street asked about: its rows' lines.
  var _others = <BanStreetId, List<OtherSectorLine>>{};

  /// The streets the index was asked about, answered or not: each once.
  var _askedOthers = <BanStreetId>{};

  /// The open secteur's centre, which the rows do not name.
  RescueCentre? _centre;

  @override
  ImportState build() {
    _numbers = {};
    _others = {};
    _askedOthers = {};
    // `ref.watch`: opening another secteur builds the list again.
    final sector = ref.watch(currentSectorProvider);
    _centre = sector?.centre;
    if (sector == null) return const ImportState();
    final listening = ref
        .watch(observeSectorCommunesProvider)(sector.id)
        .listen(_showCommunes);
    ref.onDispose(listening.cancel);
    return const ImportState();
  }

  /// The secteur's communes are [communes]: chips for them, and the streets
  /// of the first while the one chosen is not among them.
  void _showCommunes(List<SectorCommune> communes) {
    final options = List<CommuneOption>.unmodifiable([
      for (final commune in communes) CommuneOption.ofSector(commune),
    ]);
    state = state.copyWith(sectorCommunes: options);
    final chosen = state.commune?.inseeCode;
    if (options.isEmpty ||
        options.any((option) => option.inseeCode == chosen)) {
      return;
    }
    unawaited(chooseCommune(options.first, label: options.first.name));
  }

  /// The « Commune » field changed to [text]: forgets any chosen commune
  /// and, after a short pause in the typing, searches.
  Future<void> typeCommune(String text) async {
    final typing = ++_typing;
    _listing++;
    final tooShort = characterCount(text.trim()) < SearchCommunes.minLength;
    state = state.copyWith(
      query: text,
      searching: !tooShort,
      suggestions: tooShort ? const NoSuggestions() : null,
      commune: () => null,
      streets: const NoCommuneChosen(),
      filter: '',
      run: const ImportNotStarted(),
    );
    if (tooShort) return;

    await Future<void>.delayed(ref.read(communeSearchDelayProvider));
    if (!ref.mounted || typing != _typing) return;
    final found = await ref.read(searchCommunesProvider)(text);
    if (!ref.mounted || typing != _typing) return;
    state = state.copyWith(
      searching: false,
      suggestions: switch (found) {
        Ok(:final value) => CommunesFound([
          for (final match in value) CommuneOption.of(match),
        ]),
        Err(:final failure) => CommuneSearchFailed(
          ImportProblem.ofSearch(failure),
        ),
      },
    );
  }

  /// A suggestion was tapped: lists the streets of [commune].
  Future<void> chooseCommune(CommuneOption commune, {required String label}) {
    _typing++;
    state = state.copyWith(
      query: label,
      searching: false,
      suggestions: const NoSuggestions(),
      commune: () => commune,
      filter: '',
      run: const ImportNotStarted(),
    );
    return _listStreets();
  }

  /// « Réessayer » after the streets could not be listed.
  Future<void> retryStreets() => _listStreets();

  Future<void> _listStreets() async {
    final commune = state.commune!;
    final listing = ++_listing;
    state = state.copyWith(streets: const LoadingStreets());

    // Both use cases are read now: once the screen has left, `ref` can no
    // longer be used, and the answers below may come after that.
    final listCommuneStreets = ref.read(listCommuneStreetsProvider);
    final findImported = ref.read(findImportedStreetsProvider);

    final listed = await listCommuneStreets(commune.inseeCode);
    final imported = switch (listed) {
      Ok(:final value) => await findImported(
        value.streets.map((street) => street.id),
      ),
      Err() => const <BanStreetId, ImportedStreetState>{},
    };
    // The user may have typed another commune, or left, meanwhile.
    if (!ref.mounted || listing != _listing) return;
    state = state.copyWith(
      streets: switch (listed) {
        Err(:final failure) => StreetsFailed(
          ImportProblem.ofDirectory(failure),
        ),
        Ok(:final value) => StreetsLoaded(
          [
            for (final street in value.streets)
              StreetChoice(
                id: street.id,
                name: street.name.text,
                numberCount: street.numberCount,
                alreadyImported:
                    imported[street.id] == ImportedStreetState.active,
                inCorbeille:
                    imported[street.id] == ImportedStreetState.inCorbeille,
                checked: imported[street.id] == ImportedStreetState.active,
                others: _others[street.id] ?? const [],
              ),
          ]..sort(_byName),
        ),
      },
    );
  }

  static int _byName(StreetChoice a, StreetChoice b) {
    final byName = compareFrench(a.name, b.name);
    return byName != 0 ? byName : a.id.value.compareTo(b.id.value);
  }

  /// The « Filtrer les rues… » field changed.
  void filter(String text) => state = state.copyWith(filter: text);

  /// Ticks or unticks the street [id]; a street already imported stays as
  /// it is. Unticked, it loses its part.
  void toggle(BanStreetId id) {
    _update(
      (street) => street.id == id && street.selectable
          ? (street.checked
                ? street.unticked()
                : street.copyWith(checked: true))
          : street,
    );
    _askOthersOfTicked();
  }

  /// « Tout cocher » / « Tout décocher »: ticks (or unticks) every street
  /// the filter shows, so « Filtrer » then « Tout cocher » takes all the
  /// « Chemin… » at once.
  void checkAllVisible({required bool checked}) {
    final visible = {for (final street in state.visibleStreets) street.id};
    _update(
      (street) => !visible.contains(street.id) || !street.selectable
          ? street
          : checked
          ? street.copyWith(checked: true)
          : street.unticked(),
    );
    _askOthersOfTicked();
  }

  /// Asks the shared index about each street ticked to be added, once.
  void _askOthersOfTicked() {
    for (final street in _listed()) {
      if (street.toImport && _askedOthers.add(street.id)) {
        unawaited(_readOthers(street.id));
      }
    }
  }

  Future<void> _readOthers(BanStreetId id) async {
    final others = await ref.read(readOtherSectorPartsProvider)(id);
    if (!ref.mounted || others.isEmpty) return;
    final lines = OtherSectorLine.of(others, _centre);
    _others = {..._others, id: lines};
    _update(
      (street) => street.id == id ? street.copyWith(others: lines) : street,
    );
  }

  /// The streets listed; none while no commune's are.
  List<StreetChoice> _listed() => switch (state.streets) {
    StreetsLoaded(:final streets) => streets,
    NoCommuneChosen() || LoadingStreets() || StreetsFailed() => const [],
  };

  /// « Toute la rue › » under the street [id] ticked: what « Partie de la
  /// rue » opens on, the street's numbers read first (network), once.
  ///
  /// Nothing opens for a street not ticked, one of the Corbeille (it comes
  /// back as it went), one whose numbers are being read, or while the
  /// streets are being added.
  Future<PartOpening> openPart(BanStreetId id) async {
    final street = _choiceOf(id);
    if (street == null ||
        !street.partChoosable ||
        street.readingPart ||
        state.importing) {
      return const PartNotOpened();
    }
    var numbers = _numbers[id];
    if (numbers == null) {
      _setReading(id, reading: true);
      final read = await ref.read(readStreetNumbersProvider)(id);
      if (!ref.mounted) return const PartNotOpened();
      _setReading(id, reading: false);
      switch (read) {
        case Err(failure: AddressDirectoryFailure.noNetwork):
          return const PartUnreadable(PartReadProblem.noNetwork);
        case Err(
          failure: AddressDirectoryFailure.serviceError ||
              AddressDirectoryFailure.notFound,
        ):
          return const PartUnreadable(PartReadProblem.unavailable);
        case Ok(:final value):
          numbers = _numbers[id] = value;
      }
    }
    // As it is now: unticked meanwhile, or the streets being added, it is
    // too late.
    final now = _choiceOf(id);
    if (now == null || !now.partChoosable || state.importing) {
      return const PartNotOpened();
    }
    return PartToChoose(
      StreetPartRequest(
        streetName: now.name,
        choice: numbers.partChoice(part: now.part),
        banId: id,
      ),
    );
  }

  /// « Valider » on « Partie de la rue » opened from the street [id]: it
  /// holds [part] while it stays ticked. Ignored once unticked, or while
  /// the streets are being added.
  void choosePart(BanStreetId id, StreetPart part) {
    final numbers = _numbers[id];
    if (numbers == null || state.importing) return;
    _update(
      (street) => street.id == id && street.partChoosable
          ? street.withPart(part, numbers)
          : street,
    );
  }

  void _setReading(BanStreetId id, {required bool reading}) => _update(
    (street) =>
        street.id == id ? street.copyWith(readingPart: reading) : street,
  );

  /// The row of the street [id]; null when the list has none.
  StreetChoice? _choiceOf(BanStreetId id) =>
      _listed().where((street) => street.id == id).firstOrNull;

  void _update(StreetChoice Function(StreetChoice street) change) =>
      state = state.copyWith(streets: _changed(change));

  /// The street list with [change] applied to each row; unchanged while no
  /// street is listed.
  StreetChoices _changed(StreetChoice Function(StreetChoice street) change) =>
      switch (state.streets) {
        StreetsLoaded(:final streets) => StreetsLoaded([
          for (final street in streets) change(street),
        ]),
        final other => other,
      };

  /// « Importer N rues »: imports the ticked streets, telling the progress.
  /// When some fail, the screen stays, those stay ticked, and pressing again
  /// tries them again; the others become « déjà importée », those from the
  /// Corbeille included.
  Future<void> import() async {
    if (!state.canImport) return;
    final commune = state.commune!;
    final chosen = state.toImport;
    state = state.copyWith(run: ImportRunning(0, chosen.length));

    final result = await ref.read(importReferenceAreaProvider)(
      commune.inseeCode,
      only: chosen,
      parts: state.parts,
      onProgress: (done, total) {
        // The screen may have gone (the app closed) while a street loaded.
        if (ref.mounted) {
          state = state.copyWith(run: ImportRunning(done, total));
        }
      },
    );
    if (!ref.mounted) return;
    switch (result) {
      case Err(:final failure):
        state = state.copyWith(
          run: ImportFailed(ImportProblem.ofDirectory(failure)),
        );
      case Ok(value: final report):
        final onPhone = {
          for (final outcome in report.streets)
            if (outcome is! StreetImportFailed) outcome.banId,
        };
        // One new state, so the screen never sees the import finished
        // with stale rows, or the reverse.
        state = state.copyWith(
          streets: _changed(
            (street) => onPhone.contains(street.id)
                ? street.copyWith(
                    alreadyImported: true,
                    inCorbeille: false,
                    checked: true,
                  )
                : street,
          ),
          run: ImportFinished(_summary(report)),
        );
    }
  }

  static ImportSummary _summary(ImportReport report) {
    final failures = [
      for (final outcome in report.streets)
        if (outcome case StreetImportFailed(:final failure)) failure,
      // A chosen street the commune no longer lists.
      for (final _ in report.unknownStreets) AddressDirectoryFailure.notFound,
    ];
    // `AddressDirectoryFailure` lists « no network » first: the failure the
    // user can do something about is the one told.
    failures.sort((a, b) => a.index.compareTo(b.index));
    return ImportSummary(
      imported:
          report.streets.whereType<StreetImported>().length +
          report.streets.whereType<StreetAlreadyImported>().length,
      restored: report.streets.whereType<StreetRestoredFromCorbeille>().length,
      failed: failures.length,
      failure: switch (failures) {
        [] => null,
        [final first, ...] => ImportProblem.ofDirectory(first),
      },
    );
  }
}
