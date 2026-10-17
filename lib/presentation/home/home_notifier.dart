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
import 'package:tournee_calendriers/presentation/street_card/follows_team.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';
import 'package:tournee_calendriers/presentation/street_list/street_list_state.dart';

/// The state of Accueil. `autoDispose`: it follows the streets and the
/// communes only while the screen shows.
final homeProvider = NotifierProvider.autoDispose<HomeNotifier, HomeState>(
  HomeNotifier.new,
);

/// Follows the open tournée's streets (`ObserveMyStreets`), communes and
/// team, from the phone's copy, offline too, and the street tapped on the
/// map, which the member may take or release from its card.
final class HomeNotifier extends Notifier<HomeState>
    with FollowsTeam<HomeState> {
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
          .listen(
            (communes) {
              _communes = communes;
              _show();
            },
            // The tournée can no longer be read (the member was removed):
            // the communes last read stay.
            onError: (Object _) {},
          );
      ref.onDispose(communes.cancel);
    }
    followTeam();
    return render();
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

  /// « Me l'attribuer » or « La faire aussi » on the card: the member
  /// covers the street tapped. Works offline. A street that changed
  /// meanwhile (taken already, gone) changes nothing; the card follows it.
  Future<void> take() async {
    if (_selected case final street?) {
      await ref.read(takeStreetProvider)(street);
    }
  }

  /// « Ne plus la faire » on the card: the member stops covering the street
  /// tapped. Works offline.
  Future<void> release() async {
    if (_selected case final street?) {
      await ref.read(releaseStreetProvider)(street);
    }
  }

  void _show() => state = render();

  @override
  HomeState render() {
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
      card: switch (streets.all
          .where((street) => street.id == _selected)
          .firstOrNull) {
        final street? => StreetCardInTournee.of(
          street,
          me: ref.read(readCurrentMemberProvider)(),
          team: team,
        ),
        // None tapped, or the street went to the Corbeille.
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
