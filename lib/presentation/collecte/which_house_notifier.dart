import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_notifier.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_view.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/home/street_row.dart';

/// « Quelle maison ? » (PLAN §5.20, mockup MarkForgotten): the tournée a
/// house was forgotten in, and the secteur's streets to find it in.
final class WhichHouseView {
  WhichHouseView({
    required this.startedAt,
    required this.housesToMark,
    required List<StreetRow> streets,
  }) : streets = List.unmodifiable(streets);

  /// « Tournée du sam. 14 nov. », at the phone's time; null once the
  /// tournée is no longer in « Collecte ».
  final DateTime? startedAt;

  /// « 1 maison à marquer ».
  final int housesToMark;

  /// The secteur's streets in French order, those whose name holds what is
  /// typed in « Rechercher une rue » (case and accents ignored).
  final List<StreetRow> streets;

  @override
  bool operator ==(Object other) =>
      other is WhichHouseView &&
      other.startedAt == startedAt &&
      other.housesToMark == housesToMark &&
      sameItems(other.streets, streets);

  @override
  int get hashCode =>
      Object.hash(startedAt, housesToMark, Object.hashAll(streets));
}

/// « Quelle maison ? » of one tournée.
///
/// `family`: one per tournée id. `autoDispose`: it follows the streets
/// only while the screen shows.
final whichHouseProvider = NotifierProvider.autoDispose
    .family<WhichHouseNotifier, WhichHouseView, RoundId>(
      WhichHouseNotifier.new,
    );

/// Follows the open secteur's streets (`ObserveStreets`, offline too) and
/// the tournée in « Collecte », and filters the streets by name.
final class WhichHouseNotifier extends Notifier<WhichHouseView> {
  WhichHouseNotifier(this.round);

  final RoundId round;

  var _streets = const <Street>[];
  var _filter = '';

  @override
  WhichHouseView build() {
    final streets = ref
        .watch(observeStreetsProvider)()
        .listen(
          (streets) {
            _streets = streets;
            state = _render();
          },
          // The streets can no longer be read (the member left): none.
          onError: (Object _) {
            _streets = const [];
            state = _render();
          },
        );
    ref.onDispose(streets.cancel);
    // `ref.listen` rather than `ref.watch`: « 1 maison à marquer » follows
    // the tournée without the streets being listened to again.
    ref.listen(collecteProvider, (_, _) => state = _render());
    return _render();
  }

  /// « Rechercher une rue »: only the streets whose name holds [text].
  void filter(String text) {
    _filter = text;
    state = _render();
  }

  WhichHouseView _render() {
    final shown = switch (ref.read(collecteProvider)) {
      CollecteShown(:final rounds) =>
        rounds.where((each) => each.id == round).firstOrNull,
      CollecteLoading() || CollecteUnavailable() => null,
    };
    final streets = [
      for (final street in _streets)
        if (matchesFilter(street.name.text, _filter)) street,
    ]..sort((a, b) => compareFrench(a.name.text, b.name.text));
    return WhichHouseView(
      startedAt: shown?.startedAt,
      housesToMark: shown?.housesToMark ?? 0,
      streets: [
        for (final street in streets)
          if (street.progress case final progress)
            StreetRow(
              id: street.id,
              name: street.name.text,
              done: progress.visited,
              total: progress.total,
            ),
      ],
    );
  }
}
