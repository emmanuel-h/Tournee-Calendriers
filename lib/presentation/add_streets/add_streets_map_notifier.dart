import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/add_street_from_map.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/application/use_cases/find_zone_streets.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/picked_road.dart';
import 'package:tournee_calendriers/domain/map/sector_area.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_state.dart';
import 'package:tournee_calendriers/presentation/add_streets/part_opening.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';
import 'package:tournee_calendriers/presentation/street_part/other_sectors.dart';
import 'package:tournee_calendriers/presentation/street_part/street_part_state.dart';

export 'package:tournee_calendriers/presentation/add_streets/add_streets_map_state.dart';
export 'package:tournee_calendriers/presentation/add_streets/part_opening.dart';

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
///   A street the secteur has is not ticked: its card shows instead
///   (PLAN §5.19), at once from the phone's copy when its line or a house
///   dot is tapped, the ticks left as they are; « Supprimer la rue » on it
///   sends it to the Corbeille as edit mode does (`EditStreetNumbers`).
/// - **« Ajouter N rues »** never waits for a road: a street whose road is
///   not known yet is added without, and Accueil fills it later (PLAN
///   §5.3). Streets that fail stay ticked.
/// - **The search** asks the BAN in the secteur's communes; a street picked
///   moves the map to it and ticks it.
/// - **« Zone »** on, a rectangle drawn on the map lists the streets in it
///   (`FindZoneStreets`) and ticks those to add; their numbers are read
///   only when they are added. Ticks from taps and zones add up; « Zone »
///   off drops the zone and keeps the ticks.
/// - **« Toute la rue › »** under a street ticked opens « Partie de la
///   rue » (PLAN §5.15): a street of a zone has its numbers read first,
///   then kept for adding. The part chosen goes with the tick, and adding
///   stores only its numbers.
/// - **Other secteurs**: what they hold of a street ticked, or listed in a
///   zone, is read from the shared index in the background, once per
///   street, and said under its row (« Secteur 12 : impairs 19–41 »);
///   nothing when it cannot be read, and nothing waits for it.
///
/// Answers come back in any order: each one ticks what it found, except
/// once « Tout décocher » was pressed after its tap, or while the streets
/// are being added.
final class AddStreetsMapNotifier extends Notifier<AddStreetsMapState> {
  /// How much of the map shows around a street picked among the search
  /// results: the street and its neighbours, at about street zoom.
  static const foundStreetMarginMetres = 200.0;

  var _streets = const <Street>[];

  /// What the map draws of [_streets]: worked out when they change only,
  /// not at each tick or search (the stretches of the streets held in part
  /// are cut along their roads, PLAN §5.15).
  var _layers = MapLayers.of(const []);
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

  /// The streets whose numbers are being read for « Partie de la rue ».
  var _readingParts = const <BanStreetId>{};

  /// The streets found in [_zone]; null while they are looked for.
  List<ZoneStreet>? _zoneStreets;

  /// What the other secteurs hold of each street asked about, by street,
  /// once the index told it (PLAN §5.15).
  var _others = <BanStreetId, List<SectorPart>>{};

  /// The streets the index was asked about, answered or not: each once.
  var _askedOthers = <BanStreetId>{};

  /// The open secteur's centre, which the rows do not name.
  RescueCentre? _centre;

  /// Raised by each zone drawn and by « Zone » turned on or off: only the
  /// answer for the zone still shown is listed.
  var _zones = 0;

  /// The street of the secteur whose card shows, and where it was tapped;
  /// null when no card shows.
  ({StreetId id, GeoPoint? at})? _card;

  /// Raised by each tap, pick and card closed: a look-up's answer shows a
  /// card only when nothing happened since its tap.
  var _cardTaps = 0;

  @override
  AddStreetsMapState build() {
    _streets = const [];
    _layers = MapLayers.of(const []);
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
    _readingParts = const {};
    _others = {};
    _askedOthers = {};
    _centre = null;
    _card = null;
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
      _centre = sector.centre;
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
    _layers = MapLayers.of(streets);
    // The street of the card went (to the Corbeille, by a teammate too):
    // its card goes for good, even if it comes back.
    if (_card case (:final id, at: _)? when _streetOf(id) == null) {
      _card = null;
    }
    _show();
  }

  /// A tap on the map, away from the secteur's streets and the ticked
  /// ones, at [point]: ticks the street there once the BAN tells which it
  /// is, or unticks it when it is ticked already; shows its card when the
  /// secteur has it. A card shown closes.
  Future<TapAnswer> tapMap(GeoPoint point) {
    _search = const NoStreetSearch();
    _closeCard();
    return _lookUp(StreetAtPoint(point), point, toggle: true);
  }

  /// A tap on the line or a house dot of the secteur's street [id], [at]
  /// that point: its card shows in place of the selection sheet, at once
  /// and offline (PLAN §5.19). The ticks stay as they are. No card while
  /// the streets are being added, nor for a street no longer on the phone.
  void tapStreet(StreetId id, {GeoPoint? at}) {
    _search = const NoStreetSearch();
    _cardTaps++;
    _card = _run is AddRunning || _streetOf(id) == null
        ? null
        : (id: id, at: at);
    _show();
  }

  /// The card's ✕ or the back gesture, or back from edit mode: the
  /// selection sheet shows again.
  void closeCard() {
    _closeCard();
    _show();
  }

  void _closeCard() {
    _cardTaps++;
    _card = null;
  }

  /// « Supprimer la rue » on the card, once confirmed: the street goes to
  /// the Corbeille with its houses and marks, by the use case of edit mode
  /// (offline too), and the card closes. Returns the street's name, for
  /// « Rue Pasteur supprimée »; null when no card shows, or when the
  /// street went meanwhile.
  Future<String?> deleteShownStreet() async {
    final street = switch (_card) {
      (:final id, at: _)? => _streetOf(id),
      null => null,
    };
    if (street == null) return null;
    final deleted = await ref.read(editStreetNumbersProvider)(
      street.id,
      const DeleteStreet(),
    );
    if (ref.mounted && _card?.id == street.id) closeCard();
    return switch (deleted) {
      Ok() => street.name.text,
      Err() => null,
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
    _closeCard();
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
    var numbers = pick.numbers;
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
    return switch (await addStreet(
      numbers,
      shape: pick.storedRoad,
      part: pick.part,
    )) {
      // A teammate added it meanwhile: it is in the secteur all the same.
      Ok() || Err(failure: AddStreetFailure.alreadyInSector) => null,
      Err(failure: AddStreetFailure.serviceError) => AddProblem.badNumbers,
    };
  }

  /// « Toute la rue › » under the street [id] ticked: what « Partie de la
  /// rue » opens on, its numbers read first when the street was ticked in
  /// a zone (network), then kept for adding.
  ///
  /// Nothing opens for a street no longer ticked, one whose numbers are
  /// being read, one of the Corbeille (it comes back as it went), or while
  /// the streets are being added.
  Future<PartOpening> openPart(BanStreetId id) async {
    final ticked = _pickOf(id);
    if (ticked == null ||
        _run is AddRunning ||
        _readingParts.contains(id) ||
        ticked.fromCorbeille) {
      return const PartNotOpened();
    }
    if (ticked.numbers == null) {
      _readingParts = {..._readingParts, id};
      _show();
      final read = await ref.read(lookUpStreetProvider)(
        FoundStreet(ticked.match),
      );
      if (!ref.mounted) return const PartNotOpened();
      _readingParts = {..._readingParts}..remove(id);
      final refused = _keepNumbers(id, read);
      _show();
      if (refused != null) return refused;
    }
    // The tick as it is now: its numbers read, its road found meanwhile.
    final pick = _pickOf(id)!;
    return PartToChoose(
      StreetPartRequest(
        streetName: pick.match.name.text,
        choice: pick.numbers!.partChoice(road: pick.road, part: pick.part),
        banId: id,
      ),
    );
  }

  /// Keeps the numbers [read] for the street [id] with its tick; returns
  /// what to say instead of opening when they could not be read, or when
  /// the street is no longer to add.
  PartOpening? _keepNumbers(
    BanStreetId id,
    Result<LookedUpStreet, AddressDirectoryFailure> read,
  ) {
    switch (read) {
      case Err(failure: AddressDirectoryFailure.noNetwork):
        return const PartUnreadable(PartReadProblem.noNetwork);
      case Err(
        failure: AddressDirectoryFailure.serviceError ||
            AddressDirectoryFailure.notFound,
      ):
        return const PartUnreadable(PartReadProblem.unavailable);
      case Ok(value: StreetOfTheSector(:final street)):
        return PartOfStreetInSector(street.name.text);
      case Ok(value: StreetToAdd(:final numbers)):
        final pick = _pickOf(id);
        // Unticked meanwhile, or the streets are being added: too late.
        if (pick == null || _run is AddRunning) return const PartNotOpened();
        _replace(pick, pick.withNumbers(numbers));
        return null;
    }
  }

  /// « Valider » on « Partie de la rue » opened from the street [id]: it
  /// holds [part] while it stays ticked. Ignored once unticked, or while
  /// the streets are being added.
  void choosePart(BanStreetId id, StreetPart part) {
    final pick = _pickOf(id);
    if (pick == null || pick.numbers == null || _run is AddRunning) return;
    _replace(pick, pick.withPart(part));
    _show();
  }

  /// [pick] gives way to [changed], the same tick.
  void _replace(_Pick pick, _Pick changed) {
    _picks = [
      for (final each in _picks) identical(each, pick) ? changed : each,
    ];
    if (_latest?.isTick(pick) ?? false) _latest = changed;
  }

  /// « Zone » turned on, or off: off, the zone and its list go, the ticks
  /// stay.
  void toggleZone() {
    if (_run is AddRunning) return;
    _zoneMode = !_zoneMode;
    _clearZone();
    _closeCard();
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
    _closeCard();
    final ticket = _zones;
    _zone = area;
    // The zone takes the ✓'s place in view, and keeps it once gone: the
    // map does not go back to an older tick.
    _latest = null;
    _show();
    final result = await ref.read(findZoneStreetsProvider)(area);
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
        for (final street in streets) {
          if (street is ZoneStreetToAdd) _askOthers(street.match.id);
        }
        final ticked = [
          for (final street in streets)
            if (street is ZoneStreetToAdd && _pickOf(street.match.id) == null)
              _Pick.inZone(street),
        ];
        // While streets are added, the ticks wait.
        if (ticked.isNotEmpty && _run is! AddRunning) {
          _picks = [..._picks, ...ticked];
          _run = const AddIdle();
          ticked.forEach(_lookUpRoad);
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
    if (street == null) return;
    final pick = _Pick.inZone(street);
    _setPicks([..._picks, pick]);
    _lookUpRoad(pick);
  }

  /// No zone; an answer on its way for the one before is dropped.
  void _clearZone() {
    _zones++;
    _zone = null;
    _zoneStreets = null;
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
    final cardTaps = _cardTaps;
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
      // The street is the secteur's: its card, unless something was tapped
      // or closed since.
      case Ok(value: StreetOfTheSector(:final street)):
        answer = const NothingToSay();
        if (cardTaps == _cardTaps && _streetOf(street.id) != null) {
          _card = (id: street.id, at: point);
        }
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
    _lookUpRoad(pick);
    _askOthers(id);
  }

  /// Asks the shared index what the other secteurs hold of the street
  /// [id], once; its row says it when the answer comes (PLAN §5.15).
  void _askOthers(BanStreetId id) {
    if (!_askedOthers.add(id)) return;
    unawaited(_readOthers(id));
  }

  Future<void> _readOthers(BanStreetId id) async {
    final others = await ref.read(readOtherSectorPartsProvider)(id);
    if (!ref.mounted || others.isEmpty) return;
    _others = {..._others, id: others};
    _show();
  }

  /// The lines under the row of the street [id].
  List<OtherSectorLine> _linesOf(BanStreetId id) =>
      OtherSectorLine.of(_others[id] ?? const [], _centre);

  /// Asks the whole line of the street of [pick], by its BAN id, without
  /// waiting for it (PLAN §5.18).
  void _lookUpRoad(_Pick pick) => unawaited(_findRoad(pick));

  /// Draws the whole line of [pick] once it is known, if the street is
  /// still ticked by that tap or zone: it is the line stored when the
  /// street is added. A failure, or no line, leaves the tick as it was (a
  /// zone's street keeps its stretches in the zone, drawn only).
  Future<void> _findRoad(_Pick pick) async {
    final road = await ref.read(lookUpStreetShapeProvider)(
      pick.match,
      numbers: pick.numbers,
    );
    if (!ref.mounted) return;
    // The same tick, its part maybe chosen since; unticked then ticked
    // again is another tick, which asked for its own road.
    final current = _picks.where((each) => each.isTick(pick)).firstOrNull;
    if ((road, current) case (Ok(:final value), final current?)
        when !value.isEmpty) {
      _replace(current, current.withRoad(value));
      _show();
    }
  }

  /// Whether the secteur has the BAN street [id], out of the Corbeille.
  bool _inSector(BanStreetId id) =>
      _streets.any((street) => street.banId == id && !street.isDeleted);

  _Pick? _pickOf(BanStreetId id) =>
      _picks.where((pick) => pick.id == id).firstOrNull;

  /// The secteur's street [id], out of the Corbeille.
  Street? _streetOf(StreetId id) => _streets
      .where((street) => street.id == id && !street.isDeleted)
      .firstOrNull;

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

  AddStreetsMapState _render() {
    final card = switch (_card) {
      (:final id, at: _)? => _streetOf(id),
      null => null,
    };
    return AddStreetsMapState(
      layers: _layers,
      area: _focus ?? addStreetsArea(_communes, _streets),
      picked: [
        for (final pick in _picks)
          PickedStreetRow(
            id: pick.id,
            name: pick.match.name.text,
            commune: pick.match.commune.name,
            numberCount: pick.total,
            part: pick.part,
            keptCount: pick.keptCount,
            readingPart: _readingParts.contains(pick.id),
            fromCorbeille: pick.fromCorbeille,
            others: _linesOf(pick.id),
          ),
      ],
      pickedRoads: [
        for (final pick in _picks)
          PickedRoad(street: pick.id, road: pick.road, mark: pick.mark),
      ],
      lookingAt: _lookingAt,
      keepInView: switch ((_zone, _latest)) {
        (final zone?, _) => zone,
        // The same tick, not the street ticked again since.
        (null, final latest?) when _picks.any((p) => p.isTick(latest)) =>
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
      card: card == null ? null : StreetCardInSector.of(card),
      // The line the map draws for it: only the stretch held of a street
      // held in part.
      cardRoad:
          _layers.lines
              .where((line) => line.street == card?.id)
              .firstOrNull
              ?.shape ??
          StreetShape.none,
      cardPoint: card == null ? null : _card?.at,
    );
  }

  ZoneStreetRow _rowOf(ZoneStreet street) => switch (street) {
    // Added since the zone was drawn (some others failed): the secteur has
    // it now.
    ZoneStreetToAdd(:final match) when _inSector(match.id) => ZoneStreetRow(
      kind: ZoneRowKind.inSector,
      name: street.name,
      id: match.id,
    ),
    ZoneStreetToAdd(:final match, :final numberCount, :final fromCorbeille) =>
      switch (_pickOf(match.id)) {
        null => ZoneStreetRow(
          kind: ZoneRowKind.toAdd,
          name: street.name,
          id: match.id,
          numberCount: numberCount,
          fromCorbeille: fromCorbeille,
          others: _linesOf(match.id),
        ),
        final pick => ZoneStreetRow(
          kind: ZoneRowKind.toAdd,
          name: street.name,
          id: match.id,
          // « 19 numéros » as the zone listed it, until a part is chosen:
          // then « 5 numéros sur 8 », both from the numbers read.
          numberCount: pick.keptCount == null ? numberCount : pick.total,
          ticked: true,
          part: pick.part,
          keptCount: pick.keptCount,
          readingPart: _readingParts.contains(match.id),
          fromCorbeille: fromCorbeille,
          others: _linesOf(match.id),
        ),
      },
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
/// ✓ sits, its road once the map told it, and the part of it to add.
///
/// Ticked by a tap or the search, it comes with its numbers.
/// Ticked in a zone, it shows its stretches in the zone until its whole
/// line comes, and its numbers are read when its part is chosen, or when
/// it is added. Either way its whole line is asked by its BAN id
/// (`LookUpStreetShape`, PLAN §5.18): that is the one stored with the
/// street.
///
/// Immutable: each change (its road, its numbers, its part) is a copy that
/// keeps the [tick].
final class _Pick {
  _Pick.tapped(StreetToAdd found, {required this.mark})
    : tick = Object(),
      match = found.match,
      numberCount = found.numberCount,
      road = StreetShape.none,
      wholeRoad = false,
      numbers = found.numbers,
      fromCorbeille = found.fromCorbeille,
      part = StreetPart.whole;

  _Pick.inZone(ZoneStreetToAdd street)
    : tick = Object(),
      match = street.match,
      numberCount = street.numberCount,
      mark = street.mark,
      road = street.road,
      wholeRoad = false,
      numbers = null,
      fromCorbeille = street.fromCorbeille,
      part = StreetPart.whole;

  const _Pick._(
    this.tick, {
    required this.match,
    required this.numberCount,
    required this.mark,
    required this.road,
    required this.wholeRoad,
    required this.numbers,
    required this.fromCorbeille,
    required this.part,
  });

  /// Which tick this is: kept by each copy, new when the street is ticked
  /// again (an answer for the tick before then changes nothing).
  final Object tick;

  final StreetMatch match;

  /// How many numbers the BAN listed for the street.
  final int numberCount;
  final GeoPoint mark;

  /// What the map draws of the street: its whole line once known, until
  /// then nothing, or for a zone's street its stretches in the zone.
  final StreetShape road;

  /// Whether [road] is the whole line, looked up by the street's BAN id.
  final bool wholeRoad;

  /// The street's numbers: the tap's or the search's, or read for
  /// « Partie de la rue »;
  /// null until then for a street of a zone.
  final StreetNumbers? numbers;

  /// The street is in the Corbeille: it comes back as it went, with no
  /// part to choose.
  final bool fromCorbeille;

  /// The part of the street to add (PLAN §5.15).
  final StreetPart part;

  BanStreetId get id => match.id;

  /// Whether [other] is this tick, maybe changed since.
  bool isTick(_Pick other) => identical(tick, other.tick);

  /// How many numbers the street has: those read once they are.
  int get total => numbers?.numbers.length ?? numberCount;

  /// How many numbers [part] keeps; null for the whole street. A part is
  /// chosen only once the numbers are known.
  int? get keptCount => part.isWhole ? null : numbers!.heldBy(part).length;

  /// The road stored with the street: its whole line, none while it is not
  /// known (Accueil fills it later, PLAN §5.3).
  StreetShape get storedRoad => wholeRoad ? road : StreetShape.none;

  /// With [road], the street's whole line.
  _Pick withRoad(StreetShape road) => _copy(road: road, wholeRoad: true);

  _Pick withNumbers(StreetNumbers numbers) => _copy(numbers: numbers);

  _Pick withPart(StreetPart part) => _copy(part: part);

  _Pick _copy({
    StreetShape? road,
    bool? wholeRoad,
    StreetNumbers? numbers,
    StreetPart? part,
  }) => _Pick._(
    tick,
    match: match,
    numberCount: numberCount,
    mark: mark,
    road: road ?? this.road,
    wholeRoad: wholeRoad ?? this.wholeRoad,
    numbers: numbers ?? this.numbers,
    fromCorbeille: fromCorbeille,
    part: part ?? this.part,
  );
}
