import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/add_street_from_map.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_commune.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';
import 'package:tournee_calendriers/presentation/street_card/follows_team.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';

export 'package:tournee_calendriers/presentation/add_streets/add_streets_map_state.dart';

/// The state of the « Carte » tab. `autoDispose`: it follows the streets,
/// communes and team only while the screen shows.
final addStreetsMapProvider =
    NotifierProvider.autoDispose<AddStreetsMapNotifier, AddStreetsMapState>(
      AddStreetsMapNotifier.new,
    );

/// The « Carte » tab of « Ajouter des rues » (PLAN §5.4): follows the open
/// tournée's streets, communes and team from the phone's copy (offline
/// too), and answers the map and the search box with the street card.
///
/// - **A tap on a road** looks the street up (`LookUpStreet`, network):
///   the card of the tournée's street, or of the street to add, with its
///   road asked of the map meanwhile (`LookUpStreetShape`) and highlighted
///   as soon as it is known.
/// - **« Ajouter »** never waits for the road: the street is added with
///   the road when it is known, and given it once it comes otherwise
///   (`FillStreetShape`).
/// - **A tap on a street of the tournée** shows its card at once, offline
///   too.
/// - **The search** asks the BAN in the tournée's communes; a street
///   picked moves the map to it and shows its card.
///
/// Answers come back in any order: each lookup and search has a ticket,
/// and an answer whose ticket is no longer the last is dropped.
final class AddStreetsMapNotifier extends Notifier<AddStreetsMapState>
    with FollowsTeam<AddStreetsMapState> {
  /// How much of the map shows around a street picked among the search
  /// results: the street and its neighbours, at about street zoom.
  static const foundStreetMarginMetres = 200.0;

  var _streets = const <Street>[];
  var _communes = const <TourneeCommune>[];

  /// The area around the street picked in the search, null before.
  GeoBounds? _focus;

  /// What the card is about; null when no card shows.
  _Target? _target;
  GeoPoint? _point;

  /// The road of the street to add (or just added from the card), once
  /// the map told it.
  StreetShape _road = StreetShape.none;

  var _lookUps = 0;

  StreetSearch _search = const NoStreetSearch();
  var _found = const <StreetMatch>[];
  var _searches = 0;

  @override
  AddStreetsMapState build() {
    _streets = const [];
    _communes = const [];
    _focus = null;
    _target = null;
    _point = null;
    _road = StreetShape.none;
    _search = const NoStreetSearch();
    _found = const [];
    final streets = ref
        .watch(observeStreetsProvider)()
        .listen(
          _showStreets,
          // The streets can no longer be read: none to draw.
          onError: (Object _) => _showStreets(const []),
        );
    ref.onDispose(streets.cancel);
    // `ref.watch`: another tournée opened follows its communes.
    if (ref.watch(currentTourneeProvider) case final tournee?) {
      final communes = ref
          .watch(observeTourneeCommunesProvider)(tournee.id)
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

  void _showStreets(List<Street> streets) {
    final before = _streets;
    _streets = streets;
    // The card of a street of the tournée follows it: its progress, who
    // covers it. Gone to the Corbeille (it leaves the list), the card goes.
    if (_target case _InTournee(:final street)) {
      final id = street.id;
      if (_streetOf(id) case final fresh?) {
        _target = _InTournee(fresh);
      } else if (before.any((street) => street.id == id)) {
        _closeCard();
      }
    }
    _show();
  }

  /// A tap on the map, away from the tournée's streets, at [point]: the
  /// card of the street there, once the BAN tells which it is.
  Future<void> tapMap(GeoPoint point) {
    _search = const NoStreetSearch();
    return _lookUp(StreetAtPoint(point), point);
  }

  /// A tap on the line or a house of the tournée's street [id]: its card
  /// at once, offline too.
  void tapStreet(StreetId id) {
    final street = _streetOf(id);
    if (street == null) return;
    _lookUps++;
    _search = const NoStreetSearch();
    _target = _InTournee(street);
    _point = null;
    _road = StreetShape.none;
    _show();
  }

  /// The back gesture with a card shown: the card goes.
  void closeCard() {
    _closeCard();
    _show();
  }

  void _closeCard() {
    // A lookup on its way is dropped.
    _lookUps++;
    _target = null;
    _point = null;
    _road = StreetShape.none;
  }

  /// The search box was submitted with [text]: the streets of the
  /// tournée's communes whose name looks like it. A blank text closes the
  /// list.
  Future<void> search(String text) async {
    final ticket = ++_searches;
    if (text.trim().isEmpty) {
      clearSearch();
      return;
    }
    _search = const SearchingStreets();
    _show();
    final result = await ref.read(searchStreetProvider)(
      text,
      communes: _searchCommunes(),
    );
    if (!ref.mounted || ticket != _searches) return;
    switch (result) {
      case Ok(value: final matches):
        _found = matches;
        _search = StreetsFound([
          for (final match in matches)
            FoundStreetRow(
              id: match.id,
              name: match.name.text,
              commune: match.commune.name,
            ),
        ]);
      // A commune the BAN does not know has no street to find.
      case Err(failure: AddressDirectoryFailure.notFound):
        _found = const [];
        _search = StreetsFound(const []);
      case Err(:final failure):
        _search = StreetSearchFailed(_problemOf(failure));
    }
    _show();
  }

  /// The search's list closes (the box emptied, ✕).
  void clearSearch() {
    _searches++;
    _found = const [];
    _search = const NoStreetSearch();
    _show();
  }

  /// The street [id] was picked among the search results: the map goes to
  /// it and its card shows.
  Future<void> pick(BanStreetId id) async {
    final match = _found.where((match) => match.id == id).firstOrNull;
    if (match == null) return;
    _searches++;
    _search = const NoStreetSearch();
    _found = const [];
    _focus = GeoBounds.around([match.position])!
        .expandedBy(foundStreetMarginMetres);
    await _lookUp(FoundStreet(match), match.position);
  }

  /// « Ajouter et me l'attribuer » ([assignToMe]) or « Ajouter sans
  /// m'attribuer » on the card of a street to add: the street joins the
  /// tournée at once, with its road when the map told it already, and its
  /// card becomes the one of a street of the tournée.
  Future<void> add({required bool assignToMe}) async {
    final target = _target;
    if (target is! _ToAdd || target.adding) return;
    // Read now: the screen may close while the street is stored, and the
    // street must still be added.
    final addStreet = ref.read(addStreetFromMapProvider);
    final ticket = _lookUps;
    _target = target.copy(adding: true);
    _show();
    final result = await addStreet(
      target.found.numbers,
      assignToMe: assignToMe,
      shape: _road,
    );
    // Another card was asked for meanwhile: it stays.
    if (!ref.mounted || ticket != _lookUps) return;
    switch (result) {
      case Ok(value: final street):
        _target = _InTournee(street);
        _show();
        _fillAddedStreet();
      // A teammate added it meanwhile: its card as the tournée has it.
      case Err(failure: AddStreetFailure.alreadyInTournee):
        await _lookUp(FoundStreet(target.found.match), _point);
      case Err(failure: AddStreetFailure.serviceError):
        _target = target.copy(addFailed: true);
        _show();
    }
  }

  /// « Me l'attribuer » or « La faire aussi » on the card of a street of
  /// the tournée. Works offline; the card follows the street.
  Future<void> take() async {
    if (_target case _InTournee(:final street)) {
      await ref.read(takeStreetProvider)(street.id);
    }
  }

  /// « Ne plus la faire » on the card of a street of the member's. Works
  /// offline.
  Future<void> release() async {
    if (_target case _InTournee(:final street)) {
      await ref.read(releaseStreetProvider)(street.id);
    }
  }

  Future<void> _lookUp(StreetLookup lookup, GeoPoint? point) async {
    final ticket = ++_lookUps;
    _target = const _Looking();
    _point = point;
    _road = StreetShape.none;
    _show();
    final result = await ref.read(lookUpStreetProvider)(lookup);
    if (!ref.mounted || ticket != _lookUps) return;
    switch (result) {
      case Err(:final failure):
        _target = _Failed(_problemOf(failure));
      case Ok(value: StreetOfTheTournee(:final street)):
        _target = _InTournee(street);
      case Ok(value: final StreetToAdd found):
        _target = _ToAdd(found);
        unawaited(_showRoad(found, ticket));
    }
    _show();
  }

  /// Highlights the road of [found] once the map tells it, if the card is
  /// still the one of [ticket]; when the street was added meanwhile, gives
  /// it that road. A failure only leaves the point marked.
  Future<void> _showRoad(StreetToAdd found, int ticket) async {
    final road = await ref.read(lookUpStreetShapeProvider)(found);
    if (!ref.mounted || ticket != _lookUps) return;
    if (road case Ok(:final value)) {
      _road = value;
      _show();
      _fillAddedStreet();
    }
  }

  /// Gives the street just added from the card the road the map told,
  /// when it was added before the road came. Offline, the write waits on
  /// the phone like any other.
  void _fillAddedStreet() {
    if (_target case _InTournee(:final street)
        when street.shape.isEmpty && !_road.isEmpty) {
      unawaited(ref.read(fillStreetShapeProvider)(street.id, road: _road));
    }
  }

  Street? _streetOf(StreetId id) =>
      _streets.where((street) => street.id == id).firstOrNull;

  /// The communes the search looks in: the tournée's; for a tournée
  /// without commune (created before them), those of its streets.
  List<InseeCode> _searchCommunes() => _communes.isNotEmpty
      ? [for (final commune in _communes) commune.inseeCode]
      : {for (final street in _streets) street.commune.inseeCode}.toList();

  static LookUpProblem _problemOf(AddressDirectoryFailure failure) =>
      switch (failure) {
        AddressDirectoryFailure.noNetwork => LookUpProblem.noNetwork,
        AddressDirectoryFailure.notFound => LookUpProblem.noStreetHere,
        AddressDirectoryFailure.serviceError => LookUpProblem.serviceError,
      };

  void _show() => state = render();

  @override
  AddStreetsMapState render() {
    final target = _target;
    return AddStreetsMapState(
      layers: MapLayers.of(_streets, roster: roster),
      area: _focus ?? addStreetsArea(_communes, _streets),
      selectedRoad: switch (target) {
        // A street just added keeps the road the card found until its own
        // comes back from storage.
        _InTournee(:final street) when !street.shape.isEmpty => street.shape,
        _ => _road,
      },
      selectedPoint: _point,
      card: switch (target) {
        null => null,
        _Looking() => const StreetCardLoading(),
        _Failed(:final problem) => StreetCardFailed(problem),
        _ToAdd(:final found, :final adding, :final addFailed) =>
          StreetCardToAdd(
            name: found.match.name.text,
            commune: found.match.commune.name,
            numberCount: found.numberCount,
            adding: adding,
            addFailed: addFailed,
          ),
        _InTournee(:final street) => StreetCardInTournee.of(
          street,
          me: ref.read(readCurrentMemberProvider)(),
          team: team,
        ),
      },
      search: _search,
    );
  }
}

/// What the card is about. `sealed`: [AddStreetsMapNotifier.render] shows
/// each case.
sealed class _Target {
  const _Target();
}

final class _Looking extends _Target {
  const _Looking();
}

final class _Failed extends _Target {
  const _Failed(this.problem);

  final LookUpProblem problem;
}

/// A street to add.
final class _ToAdd extends _Target {
  const _ToAdd(this.found, {this.adding = false, this.addFailed = false});

  final StreetToAdd found;
  final bool adding;
  final bool addFailed;

  /// The same street, being added, or refused.
  _ToAdd copy({bool adding = false, bool addFailed = false}) =>
      _ToAdd(found, adding: adding, addFailed: addFailed);
}

/// A street of the tournée, as last read.
final class _InTournee extends _Target {
  const _InTournee(this.street);

  final Street street;
}
