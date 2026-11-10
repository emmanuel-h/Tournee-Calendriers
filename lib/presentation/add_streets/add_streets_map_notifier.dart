import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/add_street_from_map.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/picked_road.dart';
import 'package:tournee_calendriers/domain/map/sector_area.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';

export 'package:tournee_calendriers/presentation/add_streets/add_streets_map_state.dart';

/// The state of the « Carte » tab. `autoDispose`: it follows the streets
/// and communes, and keeps the ticks, only while the screen is open.
final addStreetsMapProvider =
    NotifierProvider.autoDispose<AddStreetsMapNotifier, AddStreetsMapState>(
      AddStreetsMapNotifier.new,
    );

/// The « Carte » tab of « Ajouter des rues » (PLAN §5.14, Pick mockup):
/// follows the open secteur's streets and communes from the phone's copy
/// (offline too), ticks the streets tapped on the map or picked in the
/// search, and adds them all at once.
///
/// - **A tap on a road** looks the street up (`LookUpStreet`, network) and
///   ticks it; its road is asked of the map meanwhile (`LookUpStreetShape`)
///   and drawn as soon as it is known. A tap on a ticked street unticks it.
///   A street the secteur has is not ticked: the tap says so.
/// - **« Ajouter N rues »** never waits for a road: a street whose road is
///   not known yet is added without, and Accueil fills it later (PLAN
///   §5.3). Streets that fail stay ticked.
/// - **The search** asks the BAN in the secteur's communes; a street picked
///   moves the map to it and ticks it.
///
/// Answers come back in any order: each one ticks what it found, except
/// once « Tout décocher » was pressed after its tap, or while the streets
/// are being added.
final class AddStreetsMapNotifier extends Notifier<AddStreetsMapState> {
  /// How much of the map shows around a street picked among the search
  /// results: the street and its neighbours, at about street zoom.
  static const foundStreetMarginMetres = 200.0;

  var _streets = const <Street>[];
  var _communes = const <SectorCommune>[];

  /// The area around the street picked in the search, null before.
  GeoBounds? _focus;

  /// The streets ticked, in the order they were.
  var _picks = const <_Pick>[];

  /// Where the last tap is being looked up; null once it is answered.
  GeoPoint? _lookingAt;

  /// Raised by each look-up: only the last one's answer takes its point
  /// off the map.
  var _lookUps = 0;

  /// Raised by « Tout décocher »: an answer to a tap made before it ticks
  /// nothing.
  var _clears = 0;

  AddRun _run = const AddIdle();

  StreetSearch _search = const NoStreetSearch();
  var _found = const <StreetMatch>[];
  var _searches = 0;

  @override
  AddStreetsMapState build() {
    _streets = const [];
    _communes = const [];
    _focus = null;
    _picks = const [];
    _lookingAt = null;
    _run = const AddIdle();
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
    // `ref.watch`: another secteur opened follows its communes.
    if (ref.watch(currentSectorProvider) case final sector?) {
      final communes = ref
          .watch(observeSectorCommunesProvider)(sector.id)
          .listen(
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
    _show();
  }

  /// A tap on the map, away from the secteur's streets and the ticked
  /// ones, at [point]: ticks the street there once the BAN tells which it
  /// is, or unticks it when it is ticked already.
  Future<TapAnswer> tapMap(GeoPoint point) {
    _search = const NoStreetSearch();
    return _lookUp(StreetAtPoint(point), point, toggle: true);
  }

  /// A tap on the line or a house of the secteur's street [id]: it is in
  /// the secteur already, which needs no network to say.
  TapAnswer tapStreet(StreetId id) {
    _search = const NoStreetSearch();
    _show();
    return switch (_streetOf(id)) {
      final street? => AlreadyInSector(street.name.text),
      null => const NothingToSay(),
    };
  }

  /// The ✕ of a row of the sheet, or a tap on a ticked road or its ✓ disc:
  /// the street [id] is no longer ticked.
  void untick(BanStreetId id) {
    if (_run is AddRunning) return;
    _setPicks([
      for (final pick in _picks)
        if (pick.id != id) pick,
    ]);
  }

  /// « Tout décocher »: no street ticked, and the look-ups on their way
  /// will tick none.
  void untickAll() {
    if (_run is AddRunning) return;
    _clears++;
    _lookingAt = null;
    _setPicks(const []);
  }

  /// The ticks changed: a failure told before no longer applies.
  void _setPicks(List<_Pick> picks) {
    _picks = picks;
    _run = const AddIdle();
    _show();
  }

  /// The search box was submitted with [text]: the streets of the
  /// secteur's communes whose name looks like it. A blank text closes the
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
  /// it and it is ticked (it stays ticked if it was).
  Future<TapAnswer> pick(BanStreetId id) async {
    final match = _found.where((match) => match.id == id).firstOrNull;
    if (match == null) return const NothingToSay();
    _searches++;
    _search = const NoStreetSearch();
    _found = const [];
    _focus = GeoBounds.around([match.position])!
        .expandedBy(foundStreetMarginMetres);
    return _lookUp(FoundStreet(match), match.position, toggle: false);
  }

  /// « Ajouter N rues »: adds the ticked streets one after the other,
  /// telling the progress. Returns how many are now in the secteur when
  /// every one is; null when some failed (they stay ticked and the state
  /// says why), or when there was nothing to add.
  ///
  /// Once started, it goes to the end even if the screen closes.
  Future<int?> add() async {
    if (_picks.isEmpty || _run is AddRunning) return null;
    // Read now: the screen may close while the streets are stored, and
    // they must still be added.
    final addStreet = ref.read(addStreetFromMapProvider);
    final chosen = _picks;
    final failed = <BanStreetId>{};
    var stored = 0;
    _setRun(AddRunning(0, chosen.length));
    for (final pick in chosen) {
      // Its road may have come since the button was pressed.
      final latest = _pickOf(pick.id) ?? pick;
      switch (await addStreet(latest.found.numbers, shape: latest.road)) {
        // A teammate added it meanwhile: it is in the secteur all the same.
        case Ok() || Err(failure: AddStreetFailure.alreadyInSector):
          stored++;
        case Err(failure: AddStreetFailure.serviceError):
          failed.add(pick.id);
      }
      _setRun(AddRunning(stored + failed.length, chosen.length));
    }
    _picks = [
      for (final pick in _picks)
        if (failed.contains(pick.id)) pick,
    ];
    _setRun(failed.isEmpty ? const AddIdle() : AddFailed(failed.length));
    return failed.isEmpty ? stored : null;
  }

  void _setRun(AddRun run) {
    _run = run;
    if (ref.mounted) _show();
  }

  Future<TapAnswer> _lookUp(
    StreetLookup lookup,
    GeoPoint point, {
    required bool toggle,
  }) async {
    if (_run is AddRunning) {
      _show();
      return const NothingToSay();
    }
    final ticket = ++_lookUps;
    final clears = _clears;
    _lookingAt = point;
    _show();
    final result = await ref.read(lookUpStreetProvider)(lookup);
    if (!ref.mounted) return const NothingToSay();
    if (ticket == _lookUps) _lookingAt = null;
    if (clears != _clears || _run is AddRunning) {
      _show();
      return const NothingToSay();
    }
    final TapAnswer answer;
    switch (result) {
      case Err(:final failure):
        answer = LookUpFailed(_problemOf(failure));
      case Ok(value: StreetOfTheSector(:final street)):
        answer = AlreadyInSector(street.name.text);
      case Ok(value: final StreetToAdd found):
        answer = const NothingToSay();
        _tick(found, point, toggle: toggle);
    }
    _show();
    return answer;
  }

  /// Ticks [found], its ✓ at [mark], and asks the map for its road; when
  /// it is ticked already, unticks it if [toggle].
  void _tick(StreetToAdd found, GeoPoint mark, {required bool toggle}) {
    final id = found.match.id;
    if (_pickOf(id) != null) {
      if (toggle) untick(id);
      return;
    }
    final pick = _Pick(found, mark: mark, road: StreetShape.none);
    _picks = [..._picks, pick];
    _run = const AddIdle();
    unawaited(_findRoad(pick));
  }

  /// Draws the road of [pick] once the map tells it, if the street is still
  /// ticked by that tap. A failure, or no road, leaves the ✓ alone.
  Future<void> _findRoad(_Pick pick) async {
    final road = await ref.read(lookUpStreetShapeProvider)(pick.found);
    if (!ref.mounted) return;
    if (road case Ok(:final value)) {
      // `identical`: unticked then ticked again is another tick, which
      // asked for its own road.
      _picks = [
        for (final each in _picks)
          identical(each, pick) ? each.withRoad(value) : each,
      ];
      _show();
    }
  }

  _Pick? _pickOf(BanStreetId id) =>
      _picks.where((pick) => pick.id == id).firstOrNull;

  Street? _streetOf(StreetId id) =>
      _streets.where((street) => street.id == id).firstOrNull;

  /// The communes the search looks in: the secteur's; for a secteur
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

  void _show() => state = _render();

  AddStreetsMapState _render() => AddStreetsMapState(
    layers: MapLayers.of(_streets),
    area: _focus ?? addStreetsArea(_communes, _streets),
    picked: [
      for (final pick in _picks)
        PickedStreetRow(
          id: pick.id,
          name: pick.found.match.name.text,
          commune: pick.found.match.commune.name,
          numberCount: pick.found.numberCount,
        ),
    ],
    pickedRoads: [
      for (final pick in _picks)
        PickedRoad(street: pick.id, road: pick.road, mark: pick.mark),
    ],
    lookingAt: _lookingAt,
    search: _search,
    run: _run,
  );
}

/// A street ticked: what the BAN told of it (its numbers, to add it), where
/// its ✓ sits, and its road once the map told it.
final class _Pick {
  const _Pick(this.found, {required this.mark, required this.road});

  final StreetToAdd found;
  final GeoPoint mark;
  final StreetShape road;

  BanStreetId get id => found.match.id;

  _Pick withRoad(StreetShape road) => _Pick(found, mark: mark, road: road);
}
