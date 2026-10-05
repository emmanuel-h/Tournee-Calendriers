import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/edit_street/edit_street_state.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';

/// The state of the edit mode of one street (`family`: one per street id;
/// `autoDispose`: it stops following the street, and forgets its last
/// change, when the screen goes).
final editStreetProvider = NotifierProvider.autoDispose
    .family<EditStreetNotifier, EditStreetState, StreetId>(
      EditStreetNotifier.new,
    );

/// The edit mode of a street (PLAN §5.5): follows the street on the phone
/// (`ObserveStreet`, offline), and removes, renumbers or renames through
/// `EditStreetNumbers`, turns a building back into a house through
/// `DescribeBuilding`, and undoes the last of these (`UndoLastChange`).
/// Needs no network.
///
/// Whether marks would go with a change is asked of the domain
/// (`House.hasMarks`, `Building.hasMarks`) before anything is stored, so the
/// screen can ask the person first.
final class EditStreetNotifier extends Notifier<EditStreetState> {
  EditStreetNotifier(this.streetId);

  final StreetId streetId;

  Street? _street;
  var _read = false;

  /// The last removal, renumbering or « back to a house », for « Annuler »;
  /// the next one replaces it.
  StreetChange? _lastChange;

  @override
  EditStreetState build() {
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

  /// The name field, when the edit mode is left (« OK », ✕, back) or the
  /// keyboard's « OK » is pressed: renames the street when [text] is a
  /// valid name other than the stored one. Returns why it is refused, or
  /// null when it is fine (stored, or nothing to store).
  Future<StreetNameFailure?> renameStreet(String text) async {
    switch (StreetName.create(text)) {
      case Err(:final failure):
        return failure;
      case Ok(value: final name):
        final street = _street;
        if (street == null || street.isDeleted || street.name == name.text) {
          return null;
        }
        await ref.read(editStreetNumbersProvider)(streetId, RenameStreet(name));
        return null;
    }
  }

  /// ✕ on [number]: the house goes to the Corbeille with its marks. When it
  /// has marks, nothing happens unless [confirmed]: the screen asks first.
  Future<EditOutcome> remove(
    HouseNumber number, {
    bool confirmed = false,
  }) async {
    // A number no longer shown goes on to the use case, which refuses it.
    if ((_houseAt(number)?.hasMarks ?? false) && !confirmed) {
      return const EditNeedsConfirmation();
    }
    return _keep(
      await ref.read(editStreetNumbersProvider)(streetId, RemoveNumber(number)),
    );
  }

  /// « Changer le numéro » of the number sheet: gives the house at
  /// [number] the number typed as [text] (`3` → `3bis`), its marks kept.
  Future<RenumberOutcome> renumber(HouseNumber number, String text) async {
    final HouseNumber newNumber;
    switch (HouseNumber.parse(text)) {
      case Err(:final failure):
        return RenumberInvalid(failure);
      case Ok(:final value):
        newNumber = value;
    }
    final result = await ref.read(editStreetNumbersProvider)(
      streetId,
      RenameNumber(number, newNumber),
    );
    // Patterns inside patterns: `Err(failure: CommandRefused(reason: …))`
    // matches a refusal for that one reason.
    return switch (result) {
      Ok(value: final change) => _renumbered(change, newNumber),
      Err(failure: CommandRefused(reason: NumberChangeFailure.sameNumber)) =>
        const RenumberUnchanged(),
      Err(failure: CommandRefused(reason: NumberChangeFailure.numberTaken)) =>
        RenumberTaken(newNumber),
      Err(failure: CommandRefused(reason: NumberChangeFailure.numberRemoved)) =>
        RenumberInCorbeille(newNumber),
      Err() => const RenumberFailed(),
    };
  }

  /// « Redevenir une maison » on the building at [number]: its doors go.
  /// When one of them has marks, nothing happens unless [confirmed].
  Future<EditOutcome> backToSingleHouse(
    HouseNumber number, {
    bool confirmed = false,
  }) async {
    if ((_houseAt(number)?.building?.hasMarks ?? false) && !confirmed) {
      return const EditNeedsConfirmation();
    }
    return _keep(
      await ref.read(describeBuildingProvider)(
        streetId,
        number,
        const BackToSingleHouse(),
      ),
    );
  }

  /// « Annuler » of the snackbar: puts back what the last change replaced,
  /// once. When that is no longer possible, nothing happens.
  Future<void> undo() async {
    final change = _lastChange;
    if (change == null) return;
    _lastChange = null;
    await ref.read(undoLastChangeProvider)(change);
  }

  /// « Supprimer la rue », once confirmed: the street goes to the Corbeille
  /// with its houses and marks. Returns whether it went.
  Future<bool> deleteStreet() async => switch (await ref.read(
    editStreetNumbersProvider,
  )(streetId, const DeleteStreet())) {
    Ok() => true,
    Err() => false,
  };

  Renumbered _renumbered(StreetChange change, HouseNumber newNumber) {
    _lastChange = change;
    return Renumbered(newNumber);
  }

  /// Keeps the change of [result] for « Annuler ».
  EditOutcome _keep<F>(Result<StreetChange, CommandFailure<F>> result) {
    switch (result) {
      case Ok(value: final change):
        _lastChange = change;
        return const EditApplied();
      case Err():
        return const EditFailed();
    }
  }

  House? _houseAt(HouseNumber number) {
    for (final house in _street?.houses ?? const <House>[]) {
      if (house.number == number) return house;
    }
    return null;
  }

  EditStreetState _view() {
    if (!_read) return const EditStreetLoading();
    final street = _street;
    if (street == null || street.isDeleted) return const EditStreetGone();
    final odd = street.oddHouses;
    final even = street.evenHouses;
    return EditStreetShown(
      name: street.name,
      columns: StreetColumns.of(odd: odd.length, even: even.length),
      odd: [for (final house in odd) EditTile.of(house)],
      even: [for (final house in even) EditTile.of(house)],
    );
  }
}
