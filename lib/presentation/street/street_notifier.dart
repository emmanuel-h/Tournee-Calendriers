import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/street/follows_street.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/presentation/street/undoes_last_change.dart';

/// The state of the street screen of one street.
///
/// `family`: one notifier per street id, built with that id
/// (`streetProvider(id)`). `autoDispose`: when the screen goes away, the
/// notifier stops following the street and forgets its last change.
final streetProvider = NotifierProvider.autoDispose
    .family<StreetNotifier, StreetViewState, StreetId>(StreetNotifier.new);

/// Follows a street on the phone (`ObserveStreet`, which works offline),
/// turns a building back into a house (`DescribeBuilding`), undoes that or
/// the last status the picker stored (`keepForUndo`, `UndoLastChange`) and
/// keeps « Masquer faits » for the street.
///
/// The statuses themselves are stored by the house's status picker
/// (`houseSheetProvider`, PLAN §5.6), which hands back what it stored; the
/// screen keeps it here, as the picker is gone when « Annuler » is tapped.
final class StreetNotifier extends Notifier<StreetViewState>
    with FollowsStreet<StreetViewState>, UndoesLastChange<StreetViewState> {
  StreetNotifier(this.streetId);

  final StreetId streetId;

  var _hideDone = false;

  @override
  StreetViewState build() {
    _hideDone = ref.watch(readHideDoneProvider)(streetId);
    followStreet(streetId);
    return render();
  }

  /// « Changer en maison », chosen in the grid of the building at
  /// [number] (which asked first when a door had marks): its doors go.
  /// Returns whether it was done; « Annuler » ([undo]) brings them back.
  Future<bool> backToSingleHouse(HouseNumber number) async {
    final result = await ref.read(describeBuildingProvider)(
      streetId,
      number,
      const BackToSingleHouse(),
    );
    switch (result) {
      case Ok(value: final change):
        keepForUndo(change);
        return true;
      case Err():
        return false;
    }
  }

  /// « Masquer faits »: hides or shows the done tiles at once, and
  /// remembers the choice for this street.
  Future<void> toggleHideDone() {
    _hideDone = !_hideDone;
    state = render();
    return ref.read(saveHideDoneProvider)(streetId, hide: _hideDone);
  }

  @override
  StreetViewState render() {
    if (!streetRead) return const StreetLoading();
    final street = this.street;
    if (street == null) return const StreetGone();
    final progress = street.progress;
    final odd = street.oddHouses;
    final even = street.evenHouses;
    return StreetShown(
      name: street.name.text,
      done: progress.done,
      total: progress.total,
      nobodyHome: progress.nobodyHome,
      comeBack: progress.toComeBack,
      hideDone: _hideDone,
      columns: StreetColumns.of(odd: odd.length, even: even.length),
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
