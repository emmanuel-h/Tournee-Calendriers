import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/edit_street/add_numbers_state.dart';
import 'package:tournee_calendriers/presentation/street/follows_street.dart';

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
/// shows as already there. It is the street's own answer: the numbers are
/// added to the street in memory (`Street.addNumbers`, which stores
/// nothing) and the change it would make is shown.
final class AddNumbersNotifier extends Notifier<AddNumbersState>
    with FollowsStreet<AddNumbersState> {
  AddNumbersNotifier(this.streetId);

  final StreetId streetId;

  var _text = '';

  @override
  AddNumbersState build() {
    followStreet(streetId);
    return render();
  }

  /// The « Numéros » field changed to [text].
  void type(String text) {
    _text = text;
    state = render();
  }

  /// « Ajouter »: the numbers typed join the street, each on its side; the
  /// ones in the Corbeille come back with their marks. Returns whether the
  /// street changed (the sheet then closes).
  Future<bool> add() async {
    final street = this.street;
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
        return switch (street.addNumbers(numbers)) {
          Ok(value: (_, final added)) => NumbersPreviewed(
            numbers: numbers,
            alreadyThere: added.alreadyThere,
            fromCorbeille: [
              for (final removed in added.restored) removed.number,
            ],
          ),
          // The street refuses only when every number is shown already.
          Err() => NumbersPreviewed(
            numbers: numbers,
            alreadyThere: numbers,
            fromCorbeille: const [],
          ),
        };
    }
  }

  @override
  AddNumbersState render() {
    if (!streetRead) return const AddNumbersLoading();
    final street = this.street;
    if (street == null) return const AddNumbersGone();
    return AddNumbersShown(
      streetName: street.name.text,
      preview: _preview(street),
    );
  }
}
