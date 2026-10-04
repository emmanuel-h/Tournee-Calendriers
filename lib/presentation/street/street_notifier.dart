import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';

/// The state of the street screen of one street.
///
/// `family`: one notifier per street id, built with that id
/// (`streetProvider(id)`). `autoDispose`: when the screen goes away, the
/// notifier stops following the street and forgets its last change.
final streetProvider = NotifierProvider.autoDispose
    .family<StreetNotifier, StreetViewState, StreetId>(StreetNotifier.new);

/// Follows a street on the phone (`ObserveStreet`, which works offline),
/// cycles a house's status on a tap (`MarkHouse`), undoes the last tap
/// (`UndoLastChange`) and keeps « Masquer faits » for the street.
final class StreetNotifier extends Notifier<StreetViewState> {
  StreetNotifier(this.streetId);

  final StreetId streetId;

  /// The street last read; null until it is read, or when there is none.
  Street? _street;
  var _read = false;
  var _hideDone = false;

  /// The change of the last tap, for « Annuler »; a new tap replaces it
  /// (only the last one can be undone, PLAN §5.6).
  StreetChange? _lastChange;

  @override
  StreetViewState build() {
    _hideDone = ref.watch(readHideDoneProvider)(streetId);
    // `ref.watch` on the use case: should its repository be replaced, this
    // notifier is built again and listens to the new one.
    final subscription = ref.watch(observeStreetProvider)(streetId).listen((
      street,
    ) {
      _street = street;
      _read = true;
      state = _view();
    });
    // The subscription lives as long as the notifier; Riverpod calls this
    // when the screen no longer needs it.
    ref.onDispose(subscription.cancel);
    return _view();
  }

  /// A tap on the tile of [number]: gives the house its next status
  /// (`○ → ✓ → ✗ → ○`) and returns what changed, for the snackbar and the
  /// announcement. Null when nothing changed: the street is not read yet,
  /// the number is gone, or the tile is a building (its doors are marked
  /// one by one, so the street refuses).
  ///
  /// The new street arrives through [ObserveStreet] like any other change,
  /// so the screen shows the same thing whoever changed it.
  Future<MarkedHouse?> cycle(HouseNumber number) async {
    final house = _houseAt(number);
    if (house == null) return null;
    final result = await ref.read(markHouseProvider)(
      streetId,
      number,
      house.status.next,
    );
    switch (result) {
      case Ok(value: final change):
        _lastChange = change;
        return MarkedHouse(number: number, status: change.status);
      case Err():
        return null;
    }
  }

  /// « Annuler » of the snackbar: puts back what the last tap replaced,
  /// once. Should that be impossible (a teammate removed the number since),
  /// nothing happens: the tiles show the street as it is.
  Future<void> undo() async {
    final change = _lastChange;
    if (change == null) return;
    _lastChange = null;
    await ref.read(undoLastChangeProvider)(change);
  }

  /// « Masquer faits »: hides or shows the done tiles at once, and
  /// remembers the choice for this street.
  Future<void> toggleHideDone() {
    _hideDone = !_hideDone;
    state = _view();
    return ref.read(saveHideDoneProvider)(streetId, hide: _hideDone);
  }

  House? _houseAt(HouseNumber number) {
    for (final house in _street?.houses ?? const <House>[]) {
      if (house.number == number) return house;
    }
    return null;
  }

  StreetViewState _view() {
    if (!_read) return const StreetLoading();
    final street = _street;
    if (street == null || street.isDeleted) return const StreetGone();
    final progress = street.progress;
    final odd = street.oddHouses;
    final even = street.evenHouses;
    return StreetShown(
      name: street.name,
      done: progress.done,
      total: progress.total,
      nobodyHome: progress.nobodyHome,
      comeBack: progress.comeBack,
      hideDone: _hideDone,
      columns: switch ((odd.isEmpty, even.isEmpty)) {
        (false, true) => StreetColumns.oddOnly,
        (true, false) => StreetColumns.evenOnly,
        _ => StreetColumns.both,
      },
      odd: _tiles(odd),
      even: _tiles(even),
    );
  }

  List<HouseTile> _tiles(List<House> houses) => [
    for (final house in houses)
      if (HouseTile.of(house) case final tile
          when !(_hideDone && tile.mark is DoneMark))
        tile,
  ];
}
