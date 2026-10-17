import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/street/my_streets.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_commune.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/home/home_state.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';
import 'package:tournee_calendriers/presentation/street_list/street_list_state.dart';

/// The state of Accueil. `autoDispose`: it follows the streets and the
/// communes only while the screen shows.
final homeProvider = NotifierProvider.autoDispose<HomeNotifier, HomeState>(
  HomeNotifier.new,
);

/// Follows the open tournée's streets (`ObserveMyStreets`) and communes,
/// from the phone's copy, offline too, and the street tapped on the map.
final class HomeNotifier extends Notifier<HomeState> {
  /// The last streets read, null until the first arrive.
  MyStreets? _streets;
  var _communes = const <TourneeCommune>[];

  /// Where the map opens, kept once decided (see [HomeState.area]).
  GeoBounds? _area;
  StreetId? _selected;

  @override
  HomeState build() {
    // Riverpod keeps the notifier when it builds again (another tournée
    // opened): nothing of the tournée left may stay.
    _streets = null;
    _communes = const [];
    _area = null;
    _selected = null;
    final streets = ref
        .watch(observeMyStreetsProvider)()
        .listen(
          _showStreets,
          // The streets can no longer be read (the member left the
          // tournée): none to show.
          onError: (Object _) => _showStreets(MyStreets.none),
        );
    ref.onDispose(streets.cancel);
    // `select`: the notifier is built again when another tournée opens,
    // not when something else of the one open changes (its waiting
    // requests), which would move the map back to where it opened.
    final tournee = ref.watch(
      currentTourneeProvider.select((tournee) => tournee?.id),
    );
    if (tournee != null) {
      final communes = ref
          .watch(observeTourneeCommunesProvider)(tournee)
          .listen((communes) {
            _communes = communes;
            _show();
          });
      ref.onDispose(communes.cancel);
    }
    return _view();
  }

  void _showStreets(MyStreets streets) {
    _streets = streets;
    _show();
  }

  /// A street of the tournée was tapped on the map.
  void select(StreetId street) {
    _selected = street;
    _show();
  }

  /// The map was tapped away from the tournée's streets.
  void unselect() {
    _selected = null;
    _show();
  }

  void _show() => state = _view();

  HomeState _view() {
    final streets = _streets ?? MyStreets.none;
    // `ref.read`: whether the member visits is read with the rest, the
    // notifier needs no build of its own for it.
    final visiting = ref.read(currentTourneeProvider)?.isVisiting ?? false;
    if (_streets != null) _area ??= homeArea(_communes, streets.all);
    final progress = visiting ? streets.teamProgress : streets.myProgress;
    return HomeState(
      loading: _streets == null,
      visiting: visiting,
      done: progress.done,
      total: progress.total,
      teamPercent: streets.teamProgress.donePercent,
      mine: _rows(visiting ? streets.all : streets.mine),
      others: visiting ? const [] : _rows(streets.others),
      layers: MapLayers.of(streets.all),
      area: _area,
      selected: switch (_selected) {
        final selected? => _rows(
          streets.all.where((street) => street.id == selected),
        ).firstOrNull,
        null => null,
      },
    );
  }

  static List<StreetRow> _rows(Iterable<Street> streets) => [
    for (final street in streets)
      // `progress` adds up every door of the street: read it once.
      if (street.progress case final progress)
        StreetRow(
          id: street.id,
          name: street.name.text,
          done: progress.done,
          total: progress.total,
        ),
  ];
}
