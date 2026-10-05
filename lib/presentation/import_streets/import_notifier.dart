import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/find_imported_streets.dart';
import 'package:tournee_calendriers/application/use_cases/import_reference_area.dart';
import 'package:tournee_calendriers/application/use_cases/search_communes.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';

/// How long the « Commune » field waits after the last key before
/// searching, so typing « Villefranche » sends one request, not twelve.
/// A provider so tests can set it to zero.
final communeSearchDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 300),
);

/// The state of « Importer des rues ». `autoDispose`: each visit to the
/// screen starts afresh.
final importProvider =
    NotifierProvider.autoDispose<ImportNotifier, ImportState>(
      ImportNotifier.new,
    );

/// The import flow of the temporary start screen (PLAN §5.0): search a
/// commune, choose it, tick streets, import them. Each method is an intent
/// of the screen.
final class ImportNotifier extends Notifier<ImportState> {
  /// Raised by each key typed and each commune chosen. A search remembers
  /// the value it started with and gives up when it has changed since:
  /// that is both the debounce (typed again during the delay) and the guard
  /// against stale answers (a slow answer for « Vil » arriving after the
  /// one for « Villef »).
  var _typing = 0;

  /// The same for listing the streets of a commune.
  var _listing = 0;

  @override
  ImportState build() => const ImportState();

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
  /// it is.
  void toggle(BanStreetId id) => _update(
    (street) => street.id == id && street.selectable
        ? street.copyWith(checked: !street.checked)
        : street,
  );

  /// « Tout cocher » / « Tout décocher »: ticks (or unticks) every street
  /// the filter shows, so « Filtrer » then « Tout cocher » takes all the
  /// « Chemin… » at once.
  void checkAllVisible({required bool checked}) {
    final visible = {for (final street in state.visibleStreets) street.id};
    _update(
      (street) => visible.contains(street.id) && street.selectable
          ? street.copyWith(checked: checked)
          : street,
    );
  }

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
