import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/search_communes.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_notifier.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';

/// What « Ajouter une commune… » shows (« Nouvelle tournée », Équipe):
/// the text typed and the communes found for it.
final class CommunePickerState {
  const CommunePickerState({
    this.query = '',
    this.searching = false,
    this.suggestions = const NoSuggestions(),
  });

  /// The text of the field.
  final String query;

  /// A search for [query] is on its way: the field shows a spinner.
  final bool searching;

  /// The communes found under the field, or why there are none.
  final CommuneSuggestions suggestions;
}

/// The state of « Ajouter une commune… ». `autoDispose`: each screen that
/// shows the field starts afresh.
final communePickerProvider =
    NotifierProvider.autoDispose<CommunePickerNotifier, CommunePickerState>(
      CommunePickerNotifier.new,
    );

/// Searches geo.api.gouv.fr as the user types a commune's name, as
/// « Importer des rues » does (PLAN §5.0): from two characters, after a
/// pause in the typing ([communeSearchDelayProvider]), a late answer to
/// older text ignored. Picking a suggestion is the screen's business: it
/// then calls [clear].
final class CommunePickerNotifier extends Notifier<CommunePickerState> {
  /// Raised by each key typed and by [clear]: a search gives up when it
  /// changed since it started (debounce and stale answers alike).
  var _typing = 0;

  @override
  CommunePickerState build() => const CommunePickerState();

  /// The field changed to [text]: searches after a short pause.
  Future<void> type(String text) async {
    final typing = ++_typing;
    final tooShort = characterCount(text.trim()) < SearchCommunes.minLength;
    state = CommunePickerState(
      query: text,
      searching: !tooShort,
      suggestions: tooShort ? const NoSuggestions() : state.suggestions,
    );
    if (tooShort) return;

    await Future<void>.delayed(ref.read(communeSearchDelayProvider));
    if (!ref.mounted || typing != _typing) return;
    final found = await ref.read(searchCommunesProvider)(text);
    if (!ref.mounted || typing != _typing) return;
    state = CommunePickerState(
      query: text,
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

  /// A commune was picked: the field is empty again, a search on its way
  /// is forgotten.
  void clear() {
    _typing++;
    state = const CommunePickerState();
  }
}
