import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/sector_area.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/unreadable_street.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/home/home_state.dart';
import 'package:tournee_calendriers/presentation/home/missing_shapes.dart';
import 'package:tournee_calendriers/presentation/home/street_row.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';

/// The state of Accueil. `autoDispose`: it follows the streets and the
/// communes only while the screen shows.
final homeProvider = NotifierProvider.autoDispose<HomeNotifier, HomeState>(
  HomeNotifier.new,
);

/// Follows the open secteur's streets (`ObserveStreets`), those that cannot
/// be read (`ObserveUnreadableStreets`, #149) and its communes, from the
/// phone's copy, offline too, and the street tapped on the map.
///
/// Each time the streets change, it hands them to [MissingShapes], which
/// finds in the background the line on the map of those that have none.
final class HomeNotifier extends Notifier<HomeState> {
  /// The last streets read, null until the first arrive.
  List<Street>? _streets;

  /// The streets that cannot be read: rows of the list, nothing else.
  var _unreadable = const <UnreadableStreet>[];

  /// What the map draws of [_streets]: worked out when they change only,
  /// not when a street is tapped (the stretches of the streets held in
  /// part are cut along their roads, PLAN §5.15).
  var _layers = MapLayers.of(const []);
  var _communes = const <SectorCommune>[];

  /// Where the map opens, kept once decided (see [HomeState.area]).
  GeoBounds? _area;
  StreetId? _selected;

  @override
  HomeState build() {
    // Riverpod keeps the notifier when it builds again (another secteur
    // opened): nothing of the secteur left may stay.
    _streets = null;
    _unreadable = const [];
    _layers = MapLayers.of(const []);
    _communes = const [];
    _area = null;
    _selected = null;
    final streets = ref
        .watch(observeStreetsProvider)()
        .listen(
          _showStreets,
          // The streets can no longer be read (the member left the
          // secteur): none to show.
          onError: (Object _) => _showStreets(const []),
        );
    ref.onDispose(streets.cancel);
    final unreadable = ref
        .watch(observeUnreadableStreetsProvider)()
        .listen(
          (unreadable) {
            _unreadable = unreadable;
            _show();
          },
          // Can no longer be read (the member left the secteur): none.
          onError: (Object _) {
            _unreadable = const [];
            _show();
          },
        );
    ref.onDispose(unreadable.cancel);
    // `select`: the notifier is built again when another secteur opens,
    // not when something else of the one open changes (its waiting
    // requests), which would move the map back to where it opened.
    final sector = ref.watch(
      currentSectorProvider.select((sector) => sector?.id),
    );
    if (sector != null) {
      final communes = ref.watch(observeSectorCommunesProvider)(sector).listen(
        (communes) {
          _communes = communes;
          _show();
        },
        // The secteur can no longer be read (the member was removed):
        // the communes last read stay.
        onError: (Object _) {},
      );
      ref.onDispose(communes.cancel);
    }
    return _render();
  }

  void _showStreets(List<Street> streets) {
    _streets = streets;
    _layers = MapLayers.of(streets);
    _show();
    // `unawaited`: the shapes come in the background, and the map follows
    // them through the streets; Accueil never waits for the network.
    unawaited(ref.read(missingShapesProvider).fillAmong(streets));
  }

  /// A street of the secteur was tapped on the map.
  void select(StreetId street) {
    _selected = street;
    _show();
  }

  /// The map was tapped away from the secteur's streets, or the card
  /// closed with the back gesture or its ✕.
  void unselect() {
    _selected = null;
    _show();
  }

  /// « Supprimer la rue » on an unreadable street (an admin's): it leaves
  /// the list at once, and is deleted for the team when the network allows.
  Future<void> deleteUnreadable(StreetId street) =>
      ref.read(deleteUnreadableStreetProvider)(street);

  void _show() => state = _render();

  HomeState _render() {
    final streets = _streets ?? const <Street>[];
    if (_streets != null) _area ??= homeArea(_communes, streets);
    final rows = [
      for (final street in streets)
        // `progress` adds up every door of the street: read it once.
        if (street.progress case final progress)
          StreetRow(
            id: street.id,
            name: street.name.text,
            done: progress.visited,
            total: progress.total,
          ),
    ];
    final selected = streets
        .where((street) => street.id == _selected)
        .firstOrNull;
    return HomeState(
      loading: _streets == null,
      done: rows.fold(0, (sum, row) => sum + row.done),
      total: rows.fold(0, (sum, row) => sum + row.total),
      streets: [
        ...rows,
        for (final street in _unreadable)
          UnreadableStreetRow(id: street.id, name: street.name?.text),
      ]..sort(_inFrenchOrder),
      layers: _layers,
      area: _area,
      // None tapped, or the street went to the Corbeille: no card, no line
      // lit up.
      card: switch (selected) {
        final street? => StreetCardInSector.of(street),
        null => null,
      },
      // The line the map draws for it: only the stretch held of a street
      // held in part.
      selectedRoad:
          _layers.lines
              .where((line) => line.street == selected?.id)
              .firstOrNull
              ?.shape ??
          StreetShape.none,
    );
  }

  /// By name the French way, as `ObserveStreets` orders the streets; an
  /// unreadable street without a name last; by id among equals, so the
  /// order never depends on the sort.
  static int _inFrenchOrder(HomeRow a, HomeRow b) {
    final byName = switch ((_nameOf(a), _nameOf(b))) {
      (final a?, final b?) => compareFrench(a, b),
      (null, null) => 0,
      (null, _) => 1,
      (_, null) => -1,
    };
    return byName != 0 ? byName : a.id.value.compareTo(b.id.value);
  }

  static String? _nameOf(HomeRow row) => switch (row) {
    StreetRow(:final name) => name,
    UnreadableStreetRow(:final name) => name,
  };
}
