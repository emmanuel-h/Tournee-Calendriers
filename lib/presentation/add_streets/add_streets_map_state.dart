import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/picked_road.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';
import 'package:tournee_calendriers/presentation/street_part/other_sectors.dart';

/// What the « Carte » tab of « Ajouter des rues » shows (PLAN §5.14, Pick
/// and PickZone mockups): the secteur's streets and houses, the area the
/// map shows, the streets ticked (on the map and in the selection sheet),
/// the point being looked up, the search box's results, « Zone » and the
/// streets found in the zone drawn, how adding goes, and the card of a
/// street of the secteur tapped (PLAN §5.19, PickInSector mockup).
/// Immutable: the notifier replaces it as a whole.
final class AddStreetsMapState {
  AddStreetsMapState({
    required this.layers,
    required this.area,
    List<PickedStreetRow> picked = const [],
    List<PickedRoad> pickedRoads = const [],
    this.lookingAt,
    this.keepInView,
    this.search = const NoStreetSearch(),
    this.zoneMode = false,
    this.zone = const NoZone(),
    this.run = const AddIdle(),
    this.card,
    this.cardRoad = StreetShape.none,
    this.cardPoint,
  }) : picked = List.unmodifiable(picked),
       pickedRoads = List.unmodifiable(pickedRoads);

  /// The streets and house dots, as the domain decides them.
  final MapLayers layers;

  /// Where the map is: the secteur's communes, else its streets, until a
  /// street is picked among the search results, then around it; null (all
  /// of France) when nothing has a place on the map.
  final GeoBounds? area;

  /// The streets ticked, in the order they were: one row each in the
  /// selection sheet. Read-only.
  final List<PickedStreetRow> picked;

  /// The same streets as the map draws them: each road with a ✓ disc.
  /// Read-only.
  final List<PickedRoad> pickedRoads;

  /// Where the finger last tapped while the street there is looked up
  /// (the BAN needs a moment): marked by a dot, and the sheet says
  /// « Recherche de la rue… ». Null when nothing is looked up.
  final GeoPoint? lookingAt;

  /// What the map keeps clear of the sheet, moving if needed (#132): the
  /// zone drawn, so its handle can be reached; else the ✓ of the street
  /// last ticked by a tap or the search, while it is ticked. Null when
  /// nothing: the map stays where the user put it.
  final GeoBounds? keepInView;

  /// The search box's results.
  final StreetSearch search;

  /// Whether « Zone » is on: a drag on the map draws a rectangle instead
  /// of moving the map.
  final bool zoneMode;

  /// The zone drawn, and the streets found in it.
  final ZoneView zone;

  /// How adding the ticked streets goes.
  final AddRun run;

  /// The card of the street of the secteur last tapped, shown in place of
  /// the selection sheet (or the zone's), with « Modifier la rue » and
  /// « Supprimer la rue »; null when none shows.
  final StreetCardInSector? card;

  /// The line of the street of [card] as the map draws it (only the
  /// stretch held of a street held in part), lit up over its colour; none
  /// without a card, or for a street with no line.
  final StreetShape cardRoad;

  /// Where the street of [card] was tapped; null without a card.
  final GeoPoint? cardPoint;

  /// Whether the ticked streets are being added: the map, the ticks and
  /// the way back wait.
  bool get adding => run is AddRunning;

  /// The point the map marks with its dark dot: where the street of the
  /// card was tapped while it shows, otherwise the point being looked up.
  GeoPoint? get selectedPoint => card == null ? lookingAt : cardPoint;
}

/// A street ticked, as its row of the selection sheet shows it: « Rue
/// Pierre Morin » over « Villefranche-sur-Saône · 19 numéros », the part
/// to add (« Toute la rue › », PLAN §5.15), and its ✕.
final class PickedStreetRow {
  const PickedStreetRow({
    required this.id,
    required this.name,
    required this.commune,
    required this.numberCount,
    this.part = StreetPart.whole,
    this.keptCount,
    this.readingPart = false,
    this.fromCorbeille = false,
    this.others = const [],
  });

  /// The street ✕ unticks.
  final BanStreetId id;
  final String name;
  final String commune;

  /// How many numbers the street has.
  final int numberCount;

  /// The part of the street to add: the whole street until one is chosen.
  final StreetPart part;

  /// How many numbers [part] keeps (« 5 numéros sur 8 »); null for the
  /// whole street, which keeps [numberCount].
  final int? keptCount;

  /// Its numbers are being read to open « Partie de la rue »: the link
  /// waits.
  final bool readingPart;

  /// The street is in the Corbeille: added, it comes back as it went, its
  /// own part included, so it has no part to choose.
  final bool fromCorbeille;

  /// What other secteurs hold of the street (« Secteur 12 : impairs
  /// 19–41 »), once the shared index told it; none until then, and when it
  /// cannot be read.
  final List<OtherSectorLine> others;

  @override
  bool operator ==(Object other) =>
      other is PickedStreetRow &&
      other.id == id &&
      other.name == name &&
      other.commune == commune &&
      other.numberCount == numberCount &&
      other.part == part &&
      other.keptCount == keptCount &&
      other.readingPart == readingPart &&
      other.fromCorbeille == fromCorbeille &&
      sameItems(other.others, others);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    commune,
    numberCount,
    part,
    keptCount,
    readingPart,
    fromCorbeille,
    Object.hashAll(others),
  );

  @override
  String toString() =>
      'PickedStreetRow(${id.value}, $name, $numberCount'
      '${_partFacts(part, keptCount, readingPart, fromCorbeille, others)})';
}

/// Why a street could not be looked up, or searched; the screen says so
/// and offers « Saisir à la main », which needs no network.
enum LookUpProblem {
  /// Offline: « Connexion nécessaire pour ajouter une rue ».
  noNetwork,

  /// The BAN knows no street there (a private road, a new estate).
  noStreetHere,

  /// The address service answered with an error.
  serviceError,
}

/// What a tap on the map, or a street picked in the search, has to say.
/// The ticks themselves show in the state; only what does not show there
/// comes back, for the screen's snackbar. `sealed`: the screen handles each
/// case.
sealed class TapAnswer {
  const TapAnswer();
}

/// Nothing to say: a street was ticked or unticked, a street of the
/// secteur shows its card, or the tap was dropped (a newer « Tout
/// décocher », the streets being added, the screen gone).
final class NothingToSay extends TapAnswer {
  const NothingToSay();

  @override
  bool operator ==(Object other) => other is NothingToSay;

  @override
  int get hashCode => (NothingToSay).hashCode;
}

/// No street could be looked up, for [problem]: nothing ticked.
final class LookUpFailed extends TapAnswer {
  const LookUpFailed(this.problem);

  final LookUpProblem problem;

  @override
  bool operator ==(Object other) =>
      other is LookUpFailed && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;

  @override
  String toString() => 'LookUpFailed(${problem.name})';
}

/// A zone with more streets than a zone keeps (`zoneMaxStreets`), or too
/// large to read its roads: nothing listed, « Zone trop grande : 50 rues au
/// plus. ».
final class ZoneTooLarge extends TapAnswer {
  const ZoneTooLarge();

  @override
  bool operator ==(Object other) => other is ZoneTooLarge;

  @override
  int get hashCode => (ZoneTooLarge).hashCode;
}

/// The zone drawn on the map and the streets found in it (PLAN §5.14,
/// PickZone mockup). `sealed`: the sheet shows each case.
sealed class ZoneView {
  const ZoneView();

  /// The rectangle the map draws; null when there is none.
  GeoBounds? get area;
}

/// No zone drawn: the selection sheet shows.
final class NoZone extends ZoneView {
  const NoZone();

  @override
  GeoBounds? get area => null;

  @override
  bool operator ==(Object other) => other is NoZone;

  @override
  int get hashCode => (NoZone).hashCode;
}

/// The streets of the zone [area] are being looked for.
final class FindingZoneStreets extends ZoneView {
  const FindingZoneStreets(this.area);

  @override
  final GeoBounds area;

  @override
  bool operator ==(Object other) =>
      other is FindingZoneStreets && other.area == area;

  @override
  int get hashCode => area.hashCode;
}

/// The streets of the zone [area]: « 4 rues dans la zone », one row each.
final class ZoneStreetsFound extends ZoneView {
  ZoneStreetsFound(this.area, List<ZoneStreetRow> rows)
    : rows = List.unmodifiable(rows);

  @override
  final GeoBounds area;

  /// Read-only.
  final List<ZoneStreetRow> rows;

  @override
  bool operator ==(Object other) =>
      other is ZoneStreetsFound &&
      other.area == area &&
      sameItems(other.rows, rows);

  @override
  int get hashCode => Object.hash(area, Object.hashAll(rows));
}

/// What a row of the zone's list is about.
enum ZoneRowKind {
  /// A street to add: a checkbox, « 19 numéros ».
  toAdd,

  /// A street of the secteur: greyed, « Déjà dans le secteur ».
  inSector,

  /// A road of the map no BAN street is named after: greyed, « Aucune
  /// adresse connue ».
  noAddress,
}

/// A row of the zone's list: « ☑ Rue Pierre Morin · 19 numéros », and the
/// part to add under a street ticked (« Toute la rue › », PLAN §5.15).
final class ZoneStreetRow {
  const ZoneStreetRow({
    required this.kind,
    required this.name,
    this.id,
    this.numberCount = 0,
    this.ticked = false,
    this.part = StreetPart.whole,
    this.keptCount,
    this.readingPart = false,
    this.fromCorbeille = false,
    this.others = const [],
  });

  final ZoneRowKind kind;
  final String name;

  /// The BAN street its checkbox ticks; null for a road without address.
  final BanStreetId? id;

  /// How many numbers the BAN lists for a street to add.
  final int numberCount;

  /// Whether the street is ticked, here or by a tap on the map.
  final bool ticked;

  /// The part of a street ticked: the whole street until one is chosen.
  final StreetPart part;

  /// How many numbers [part] keeps (« 5 numéros sur 8 »); null for the
  /// whole street.
  final int? keptCount;

  /// Its numbers are being read to open « Partie de la rue ».
  final bool readingPart;

  /// The street is in the Corbeille: it has no part to choose (see
  /// [PickedStreetRow.fromCorbeille]).
  final bool fromCorbeille;

  /// What other secteurs hold of a street to add (see
  /// [PickedStreetRow.others]).
  final List<OtherSectorLine> others;

  @override
  bool operator ==(Object other) =>
      other is ZoneStreetRow &&
      other.kind == kind &&
      other.name == name &&
      other.id == id &&
      other.numberCount == numberCount &&
      other.ticked == ticked &&
      other.part == part &&
      other.keptCount == keptCount &&
      other.readingPart == readingPart &&
      other.fromCorbeille == fromCorbeille &&
      sameItems(other.others, others);

  @override
  int get hashCode => Object.hash(
    kind,
    name,
    id,
    numberCount,
    ticked,
    part,
    keptCount,
    readingPart,
    fromCorbeille,
    Object.hashAll(others),
  );

  @override
  String toString() =>
      'ZoneStreetRow(${kind.name}, $name, ${id?.value}, $numberCount, '
      '$ticked${_partFacts(part, keptCount, readingPart, fromCorbeille, others)})';
}

/// What a row says of its part when printed, after its other values;
/// nothing for the whole street, which most rows add.
String _partFacts(
  StreetPart part,
  int? keptCount,
  bool readingPart,
  bool fromCorbeille,
  List<OtherSectorLine> others,
) => [
  if (!part.isWhole) ', $part, kept: $keptCount',
  if (readingPart) ', reading',
  if (fromCorbeille) ', from the Corbeille',
  if (others.isNotEmpty) ', others: $others',
].join();

/// How adding the ticked streets goes. `sealed`: the sheet shows each case.
sealed class AddRun {
  const AddRun();
}

/// Why streets could not be added (PLAN §5.14): said above the button.
enum AddProblem {
  /// The numbers the BAN gave cannot make a street (a number twice).
  badNumbers,

  /// The numbers of a street found in a zone could not be read: offline.
  /// The streets after it were not tried.
  noNetwork,

  /// The numbers of a street found in a zone could not be read: the
  /// address service answered with an error.
  serviceError,
}

/// Nothing being added, nothing failed: « Ajouter 2 rues ».
final class AddIdle extends AddRun {
  const AddIdle();

  @override
  bool operator ==(Object other) => other is AddIdle;

  @override
  int get hashCode => (AddIdle).hashCode;
}

/// [done] of [total] streets stored: « Ajout en cours… 2/3 ».
final class AddRunning extends AddRun {
  const AddRunning(this.done, this.total);

  final int done;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is AddRunning && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);

  @override
  String toString() => 'AddRunning($done/$total)';
}

/// [failed] streets could not be added, for [problem] (the first one met).
/// They stay ticked, the others are in the secteur; the sheet says why
/// above the button.
final class AddFailed extends AddRun {
  const AddFailed(this.failed, {this.problem = AddProblem.badNumbers});

  final int failed;
  final AddProblem problem;

  @override
  bool operator ==(Object other) =>
      other is AddFailed && other.failed == failed && other.problem == problem;

  @override
  int get hashCode => Object.hash(failed, problem);

  @override
  String toString() => 'AddFailed($failed, ${problem.name})';
}

/// Where the search box is. `sealed`: the results list has a look for
/// each case.
sealed class StreetSearch {
  const StreetSearch();
}

/// Nothing searched, or the search was closed: no list.
final class NoStreetSearch extends StreetSearch {
  const NoStreetSearch();

  @override
  bool operator ==(Object other) => other is NoStreetSearch;

  @override
  int get hashCode => (NoStreetSearch).hashCode;
}

/// The address service is asked.
final class SearchingStreets extends StreetSearch {
  const SearchingStreets();

  @override
  bool operator ==(Object other) => other is SearchingStreets;

  @override
  int get hashCode => (SearchingStreets).hashCode;
}

/// The streets found, best first; none says « Aucune rue trouvée ».
final class StreetsFound extends StreetSearch {
  StreetsFound(List<FoundStreetRow> streets)
    : streets = List.unmodifiable(streets);

  /// Read-only.
  final List<FoundStreetRow> streets;

  @override
  bool operator ==(Object other) =>
      other is StreetsFound && sameItems(other.streets, streets);

  @override
  int get hashCode => Object.hashAll(streets);
}

/// The search could not be made, for [problem]
/// ([LookUpProblem.noNetwork] or [LookUpProblem.serviceError]).
final class StreetSearchFailed extends StreetSearch {
  const StreetSearchFailed(this.problem);

  final LookUpProblem problem;

  @override
  bool operator ==(Object other) =>
      other is StreetSearchFailed && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;
}

/// A street found by the search: « Rue Pierre Morin · Villefranche-sur-
/// Saône ». Picking it sends its [id] back.
final class FoundStreetRow {
  const FoundStreetRow({
    required this.id,
    required this.name,
    required this.commune,
  });

  final BanStreetId id;
  final String name;
  final String commune;

  @override
  bool operator ==(Object other) =>
      other is FoundStreetRow &&
      other.id == id &&
      other.name == name &&
      other.commune == commune;

  @override
  int get hashCode => Object.hash(id, name, commune);

  @override
  String toString() => 'FoundStreetRow(${id.value}, $name, $commune)';
}
