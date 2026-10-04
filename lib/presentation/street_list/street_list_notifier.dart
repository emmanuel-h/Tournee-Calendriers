import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// One row of « Mes rues »: a street's name and how many of its doors are
/// done (« 31/403 »).
final class StreetRow {
  const StreetRow({
    required this.id,
    required this.name,
    required this.done,
    required this.total,
  });

  /// Which street the row opens.
  final StreetId id;
  final String name;

  /// Doors done (a building counts its dwellings), out of [total].
  final int done;
  final int total;

  /// Every door done: the row shows « ✓ 8/8 » in green. A street without a
  /// door is never complete.
  bool get isComplete => total > 0 && done == total;

  /// How much of the progress bar is filled, 0 to 1.
  double get fraction => total == 0 ? 0 : done / total;

  @override
  bool operator ==(Object other) =>
      other is StreetRow &&
      other.id == id &&
      other.name == name &&
      other.done == done &&
      other.total == total;

  @override
  int get hashCode => Object.hash(id, name, done, total);
}

/// What the « Mes rues » start screen shows (PLAN §5.0). Immutable: the
/// notifier replaces it as a whole, and the screen redraws.
final class StreetListState {
  StreetListState({
    required this.loading,
    required this.streetCount,
    required List<String> communes,
    required List<StreetRow> rows,
    required this.filter,
  }) : communes = List.unmodifiable(communes),
       rows = List.unmodifiable(rows);

  /// True until the streets have been read from the phone once.
  final bool loading;

  /// How many streets are on the phone, filter or not (« Mes rues · 3 »).
  final int streetCount;

  /// The communes of those streets, each once, in French order.
  final List<String> communes;

  /// The streets the filter keeps, in French order of their names.
  final List<StreetRow> rows;

  /// The text of the « Filtrer les rues… » field.
  final String filter;

  /// No street imported yet: the screen shows its first-launch message.
  bool get isEmpty => !loading && streetCount == 0;
}

/// The state of the « Mes rues » screen. `autoDispose`: when the screen
/// goes away, the notifier stops listening to the streets.
final streetListProvider =
    NotifierProvider.autoDispose<StreetListNotifier, StreetListState>(
      StreetListNotifier.new,
    );

/// Follows the streets on the phone (`ObserveStreets`, which works offline)
/// and the filter typed above them.
final class StreetListNotifier extends Notifier<StreetListState> {
  /// The last streets read, null until the first arrive. Kept here, not in
  /// the state, so a new filter can be applied to them.
  List<Street>? _streets;
  String _filter = '';

  @override
  StreetListState build() {
    // `ref.watch` on the use case: should its repository be replaced, this
    // notifier is built again and listens to the new one.
    final subscription = ref.watch(observeStreetsProvider)().listen((streets) {
      _streets = streets;
      state = _view();
    });
    // The subscription lives as long as the notifier; Riverpod calls this
    // when the screen no longer needs it.
    ref.onDispose(subscription.cancel);
    return _view();
  }

  /// Keeps only the streets whose name holds [text], ignoring case and
  /// accents.
  void filter(String text) {
    _filter = text;
    state = _view();
  }

  StreetListState _view() {
    final streets = _streets ?? const [];
    final communes = {
      for (final street in streets) street.commune.name,
    }.toList()..sort(compareFrench);
    return StreetListState(
      loading: _streets == null,
      streetCount: streets.length,
      communes: communes,
      // The use case already sorts the streets the French way.
      rows: [
        for (final street in streets)
          if (matchesFilter(street.name, _filter))
            StreetRow(
              id: street.id,
              name: street.name,
              done: street.progress.done,
              total: street.progress.total,
            ),
      ],
      filter: _filter,
    );
  }
}
