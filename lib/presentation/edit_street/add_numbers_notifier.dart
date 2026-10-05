import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/edit_street/add_numbers_state.dart';

/// The state of the « Ajouter des numéros » sheet of one street.
final addNumbersProvider = NotifierProvider.autoDispose
    .family<AddNumbersNotifier, AddNumbersState, StreetId>(
      AddNumbersNotifier.new,
    );

/// « + numéros » (PLAN §5.5): reads the « Numéros » field at each key
/// (`parseHouseNumbers`, the domain's reading of `12bis, 21-25`), shows
/// what the street would make of it, and adds the numbers through
/// `EditStreetNumbers`. Needs no network.
///
/// The preview follows the street too: a number a teammate adds meanwhile
/// shows as already there.
final class AddNumbersNotifier extends Notifier<AddNumbersState> {
  AddNumbersNotifier(this.streetId);

  final StreetId streetId;

  Street? _street;
  var _read = false;
  var _text = '';

  @override
  AddNumbersState build() {
    final subscription = ref.watch(observeStreetProvider)(streetId).listen((
      street,
    ) {
      _street = street;
      _read = true;
      state = _view();
    });
    ref.onDispose(subscription.cancel);
    return _view();
  }

  /// The « Numéros » field changed to [text].
  void type(String text) {
    _text = text;
    state = _view();
  }

  /// « Ajouter »: the numbers typed join the street, each on its side; the
  /// ones in the Corbeille come back with their marks. Returns whether the
  /// street changed (the sheet then closes).
  Future<bool> add() async {
    final street = _street;
    if (street == null) return false;
    switch (_preview(street)) {
      case NothingTyped() || NumbersRefused():
        return false;
      // When every number is shown already, the street refuses
      // (`nothingNew`) and nothing is stored.
      case NumbersPreviewed(:final numbers):
        final result = await ref.read(editStreetNumbersProvider)(
          streetId,
          AddNumbers(numbers),
        );
        return result is Ok;
    }
  }

  NumbersPreview _preview(Street street) {
    switch (parseHouseNumbers(_text)) {
      case Err(:final failure):
        return NumbersRefused(failure);
      case Ok(value: final numbers) when numbers.isEmpty:
        return const NothingTyped();
      case Ok(value: final numbers):
        final shown = {for (final house in street.houses) house.number};
        final removed = {
          for (final house in street.removedHouses) house.number,
        };
        return NumbersPreviewed(
          numbers: numbers,
          alreadyThere: numbers.where(shown.contains).toList(),
          fromCorbeille: numbers.where(removed.contains).toList(),
        );
    }
  }

  AddNumbersState _view() {
    if (!_read) return const AddNumbersLoading();
    final street = _street;
    if (street == null || street.isDeleted) return const AddNumbersGone();
    return AddNumbersShown(streetName: street.name, preview: _preview(street));
  }
}
