import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/street_list/street_list_state.dart';

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
          if (matchesFilter(street.name.text, _filter))
            // `progress` adds up every door of the street: read it once.
            if (street.progress case final progress)
              StreetRow(
                id: street.id,
                name: street.name.text,
                done: progress.done,
                total: progress.total,
              ),
      ],
      filter: _filter,
    );
  }
}
