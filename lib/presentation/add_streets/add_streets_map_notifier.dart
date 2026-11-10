import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/add_street_from_map.dart';
import 'package:tournee_calendriers/application/use_cases/find_zone_streets.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
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
/// - **« Zone »** on, a rectangle drawn on the map lists the streets in it
///   (`FindZoneStreets`) and ticks those to add; their numbers are read
///   only when they are added. Ticks from taps and zones add up; « Zone »
///   off drops the zone and keeps the ticks.
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

  /// The street last ticked by a tap or the search, whose ✓ the map keeps
  /// in view while it is ticked; null once a zone is drawn, which the map
  /// keeps in view instead.
  _Pick? _latest;

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

  var _zoneMode = false;

  /// The zone drawn, null when none.
  GeoBounds? _zone;

  /// The streets found in [_zone]; null while they are looked for.
  List<ZoneStreet>? _zoneStreets;

  /// Raised by each zone drawn and by « Zone » turned on or off: only the
  /// answer for the zone still shown is listed.
  var _zones = 0;

  @override
  AddStreetsMapState build() {
    _streets = const [];
    _communes = const [];
    _focus = null;
    _picks = const [];
    _latest = null;
    _lookingAt = null;
    _run = const AddIdle();
    _search = const NoStreetSearch();
    _found = const [];
    _zoneMode = false;
    _zone = null;
    _zoneStreets = null;
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
  /// The screen stays open to go on adding (#134): the streets added leave
  /// the selection and show as the secteur's on the map. When every one
  /// is added, the zone shown goes too (« Zone » stays on, for the next
  /// one).
  ///
  /// A street found in a zone has its numbers read first (`LookUpStreet`);
  /// offline, it and the streets after it stay ticked.
  ///
  /// Once started, it goes to the end even if the screen closes.
  Future<int?> add() async {
    if (_picks.isEmpty || _run is AddRunning) return null;
    // Read now: the screen may close while the streets are stored, and
    // they must still be added.
    final addStreet = ref.read(addStreetFromMapProvider);
    final lookUp = ref.read(lookUpStreetProvider);
    final chosen = _picks;
    final failed = <BanStreetId>{};
    AddProblem? problem;
    var stored = 0;
    _setRun(AddRunning(0, chosen.length));
    for (final pick in chosen) {
      // Its road may have come since the button was pressed.
      final latest = _pickOf(pick.id) ?? pick;
      final outcome = problem == AddProblem.noNetwork
          // Offline: the next ones would fail the same way, each after
          // its wait.
          ? AddProblem.noNetwork
          : await _addOne(latest, addStreet, lookUp);
      if (outcome == null) {
        stored++;
      } else {
        failed.add(pick.id);
        problem ??= outcome;
      }
      _setRun(AddRunning(stored + failed.length, chosen.length));
    }
    _picks = [
      for (final pick in _picks)
        if (failed.contains(pick.id)) pick,
    ];
    if (failed.isEmpty) _clearZone();
    _setRun(
      problem == null
          ? const AddIdle()
          : AddFailed(failed.length, problem: problem),
    );
    return failed.isEmpty ? stored : null;
  }

  /// Adds the street of [pick]: null once it is in the secteur, otherwise
  /// why not.
  Future<AddProblem?> _addOne(
    _Pick pick,
    AddStreetFromMap addStreet,
    LookUpStreet lookUp,
  ) async {
    var numbers = pick.found?.numbers;
    if (numbers == null) {
      switch (await lookUp(FoundStreet(pick.match))) {
        case Ok(value: StreetToAdd(numbers: final read)):
          numbers = read;
        // A teammate added it meanwhile: it is in the secteur all the same.
        case Ok(value: StreetOfTheSector()):
          return null;
        case Err(failure: AddressDirectoryFailure.noNetwork):
          return AddProblem.noNetwork;
        case Err(
          failure: AddressDirectoryFailure.notFound ||
              AddressDirectoryFailure.serviceError,
        ):
          return AddProblem.serviceError;
      }
    }
    return switch (await addStreet(numbers, shape: pick.storedRoad)) {
      // A teammate added it meanwhile: it is in the secteur all the same.
      Ok() || Err(failure: AddStreetFailure.alreadyInSector) => null,
      Err(failure: AddStreetFailure.serviceError) => AddProblem.badNumbers,
    };
  }

  /// « Zone » turned on, or off: off, the zone and its list go, the ticks
  /// stay.
  void toggleZone() {
    if (_run is AddRunning) return;
    _zoneMode = !_zoneMode;
    _clearZone();
    _show();
  }

  /// A rectangle [area] drawn on the map, « Zone » on, however far out the
  /// map is: lists its streets and ticks those to add. With too many
  /// streets, or too large to read, nothing is listed and the answer says
  /// why.
  Future<TapAnswer> drawZone(GeoBounds area) async {
    if (!_zoneMode || _run is AddRunning) return const NothingToSay();
    _search = const NoStreetSearch();
    _clearZone();
    final ticket = _zones;
    _zone = area;
    // The zone takes the ✓'s place in view, and keeps it once gone: the
    // map does not go back to an older tick.
    _latest = null;
    _show();
    final result = await ref.read(findZoneStreetsProvider)(
      area,
      communes: _zoneCommunes(area),
    );
    if (!ref.mounted || ticket != _zones) return const NothingToSay();
    final TapAnswer answer;
    switch (result) {
      case Err(failure: FindZoneFailure.tooManyStreets):
        _clearZone();
        answer = const ZoneTooLarge();
      case Err(failure: FindZoneFailure.noNetwork):
        _clearZone();
        answer = const LookUpFailed(LookUpProblem.noNetwork);
      case Err(failure: FindZoneFailure.serviceError):
        _clearZone();
        answer = const LookUpFailed(LookUpProblem.serviceError);
      case Ok(value: final streets):
        _zoneStreets = streets;
        final ticked = [
          for (final street in streets)
            if (street is ZoneStreetToAdd && _pickOf(street.match.id) == null)
              _Pick.inZone(street),
        ];
        // While streets are added, the ticks wait.
        if (ticked.isNotEmpty && _run is! AddRunning) {
          _picks = [..._picks, ...ticked];
          _run = const AddIdle();
        }
        answer = const NothingToSay();
    }
    _show();
    return answer;
  }

  /// The checkbox of the street [id] in the zone's list: ticks it, or
  /// unticks it.
  void toggleZoneStreet(BanStreetId id) {
    if (_run is AddRunning) return;
    if (_pickOf(id) != null) {
      untick(id);
      return;
    }
    final street = (_zoneStreets ?? const [])
        .whereType<ZoneStreetToAdd>()
        .where((street) => street.match.id == id)
        .firstOrNull;
    if (street != null) _setPicks([..._picks, _Pick.inZone(street)]);
  }

  /// No zone; an answer on its way for the one before is dropped.
  void _clearZone() {
    _zones++;
    _zone = null;
    _zoneStreets = null;
  }

  /// The communes a zone's streets are matched in: the secteur's, the
  /// nearest to [zone] first (one without a centre last); for a secteur
  /// without commune, those of its streets.
  List<InseeCode> _zoneCommunes(GeoBounds zone) {
    if (_communes.isEmpty) return _searchCommunes();
    // The middle of a zone on Earth is on Earth: it cannot fail.
    final middle = (GeoPoint.create(
      latitude: (zone.south + zone.north) / 2,
      longitude: (zone.west + zone.east) / 2,
    ) as Ok<GeoPoint, GeoPointFailure>).value;
    double distance(SectorCommune commune) => switch (commune.centre) {
      null => double.infinity,
      final centre => metresBetween(centre, middle),
    };
    final nearest = [..._communes]
      ..sort((a, b) => distance(a).compareTo(distance(b)));
    return [for (final commune in nearest) commune.inseeCode];
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
    // On the road under the finger when the map told it (#132).
    final pick = _Pick.tapped(found, mark: found.mark ?? mark);
    _picks = [..._picks, pick];
    _latest = pick;
    _run = const AddIdle();
    unawaited(_findRoad(pick));
  }

  /// Draws the road of [pick] once the map tells it, if the street is still
  /// ticked by that tap. A failure, or no road, leaves the ✓ alone.
  Future<void> _findRoad(_Pick pick) async {
    final road = await ref.read(lookUpStreetShapeProvider)(pick.found!);
    if (!ref.mounted) return;
    if (road case Ok(:final value)) {
      // `identical`: unticked then ticked again is another tick, which
      // asked for its own road.
      final drawn = pick.withRoad(value);
      _picks = [
        for (final each in _picks) identical(each, pick) ? drawn : each,
      ];
      if (identical(_latest, pick)) _latest = drawn;
      _show();
    }
  }

  /// Whether the secteur has the BAN street [id], out of the Corbeille.
  bool _inSector(BanStreetId id) =>
      _streets.any((street) => street.banId == id && !street.isDeleted);

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
          name: pick.match.name.text,
          commune: pick.match.commune.name,
          numberCount: pick.numberCount,
        ),
    ],
    pickedRoads: [
      for (final pick in _picks)
        PickedRoad(street: pick.id, road: pick.road, mark: pick.mark),
    ],
    lookingAt: _lookingAt,
    keepInView: switch ((_zone, _latest)) {
      (final zone?, _) => zone,
      // `identical`: the same tick, not the street ticked again since.
      (null, final latest?) when _picks.any((p) => identical(p, latest)) =>
        GeoBounds.around([latest.mark]),
      _ => null,
    },
    search: _search,
    zoneMode: _zoneMode,
    zone: switch ((_zone, _zoneStreets)) {
      (null, _) => const NoZone(),
      (final area?, null) => FindingZoneStreets(area),
      (final area?, final streets?) => ZoneStreetsFound(area, [
        for (final street in streets) _rowOf(street),
      ]),
    },
    run: _run,
  );

  ZoneStreetRow _rowOf(ZoneStreet street) => switch (street) {
    // Added since the zone was drawn (some others failed): the secteur has
    // it now.
    ZoneStreetToAdd(:final match) when _inSector(match.id) => ZoneStreetRow(
      kind: ZoneRowKind.inSector,
      name: street.name,
      id: match.id,
    ),
    ZoneStreetToAdd(:final match, :final numberCount) => ZoneStreetRow(
      kind: ZoneRowKind.toAdd,
      name: street.name,
      id: match.id,
      numberCount: numberCount,
      ticked: _pickOf(match.id) != null,
    ),
    ZoneStreetInSector(:final match) => ZoneStreetRow(
      kind: ZoneRowKind.inSector,
      name: street.name,
      id: match.id,
    ),
    ZoneRoadWithoutAddress() => ZoneStreetRow(
      kind: ZoneRowKind.noAddress,
      name: street.name,
    ),
  };
}

/// A street ticked: the BAN street, how many numbers it brings, where its
/// ✓ sits, and its road once the map told it.
///
/// Ticked by a tap or the search, it comes with its numbers ([found]) and
/// its road is asked of the map (`LookUpStreetShape`), whole: it is stored
/// with the street. Ticked in a zone, its road is the map's in the zone's
/// tiles, drawn only (it may be cut where they end), and its numbers are
/// read when it is added.
final class _Pick {
  _Pick.tapped(StreetToAdd this.found, {required this.mark})
    : match = found.match,
      numberCount = found.numberCount,
      road = StreetShape.none;

  _Pick.inZone(ZoneStreetToAdd street)
    : found = null,
      match = street.match,
      numberCount = street.numberCount,
      mark = street.mark,
      road = street.road;

  const _Pick._(
    this.found, {
    required this.match,
    required this.numberCount,
    required this.mark,
    required this.road,
  });

  final StreetToAdd? found;
  final StreetMatch match;
  final int numberCount;
  final GeoPoint mark;
  final StreetShape road;

  BanStreetId get id => match.id;

  /// The road stored with the street: none for a zone's, which Accueil
  /// fills from the street's houses (PLAN §5.3).
  StreetShape get storedRoad => found == null ? StreetShape.none : road;

  _Pick withRoad(StreetShape road) => _Pick._(
    found,
    match: match,
    numberCount: numberCount,
    mark: mark,
    road: road,
  );
}
