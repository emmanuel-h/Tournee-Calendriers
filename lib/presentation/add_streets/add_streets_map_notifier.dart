import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_commune.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';

/// What the « Carte » tab of « Ajouter des rues » shows (PLAN §5.4): the
/// tournée's streets and houses, and the area the map opens on.
final class AddStreetsMapState {
  const AddStreetsMapState({required this.layers, required this.area});

  /// The streets and house dots, as the domain decides them.
  final MapLayers layers;

  /// Where the map opens: the tournée's communes, else its streets; null
  /// (all of France) when neither has a place on the map.
  final GeoBounds? area;
}

/// The state of the « Carte » tab. `autoDispose`: it follows the streets
/// and communes only while the screen shows.
final addStreetsMapProvider =
    NotifierProvider.autoDispose<AddStreetsMapNotifier, AddStreetsMapState>(
      AddStreetsMapNotifier.new,
    );

/// Follows the open tournée's streets and communes, from the phone's copy
/// (offline too), and keeps the map's layers and area up to date. The
/// street card, the search and the manual entry come with #31.
final class AddStreetsMapNotifier extends Notifier<AddStreetsMapState> {
  var _streets = const <Street>[];
  var _communes = const <TourneeCommune>[];

  @override
  AddStreetsMapState build() {
    _streets = const [];
    _communes = const [];
    final streets = ref
        .watch(observeStreetsProvider)()
        .listen(
          (streets) {
            _streets = streets;
            _show();
          },
          // The streets can no longer be read: none to draw.
          onError: (Object _) {
            _streets = const [];
            _show();
          },
        );
    ref.onDispose(streets.cancel);
    // `ref.watch`: another tournée opened follows its communes.
    if (ref.watch(currentTourneeProvider) case final tournee?) {
      final communes = ref
          .watch(observeTourneeCommunesProvider)(tournee.id)
          .listen((communes) {
            _communes = communes;
            _show();
          });
      ref.onDispose(communes.cancel);
    }
    return _view();
  }

  void _show() => state = _view();

  AddStreetsMapState _view() => AddStreetsMapState(
    layers: MapLayers.of(_streets),
    area: addStreetsArea(_communes, _streets),
  );
}
