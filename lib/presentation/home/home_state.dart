import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';
import 'package:tournee_calendriers/presentation/street_list/street_list_state.dart';

/// What Accueil shows (PLAN §5.3, Home and HomeZoom mockups): the map of
/// the tournée and its « Mes rues » panel. Immutable: the notifier
/// replaces it as a whole, and the screen redraws.
final class HomeState {
  HomeState({
    required this.loading,
    required this.visiting,
    required this.done,
    required this.total,
    required this.teamPercent,
    required List<StreetRow> mine,
    required List<StreetRow> others,
    required this.layers,
    required this.area,
    required this.card,
    required this.selectedRoad,
  }) : mine = List.unmodifiable(mine),
       others = List.unmodifiable(others);

  /// True until the streets have been read once.
  final bool loading;

  /// An admin visits the tournée without being in its team (PLAN §5.12):
  /// the panel reads « Rues » and lists every street in [mine].
  final bool visiting;

  /// The doors done of the streets in [mine], out of [total] (« Mes rues ·
  /// 43/62 »).
  final int done;
  final int total;

  /// The share of the whole tournée's doors done (« Équipe : 41 % »).
  final int teamPercent;

  /// « Mes rues »: the streets the member covers, in French order; every
  /// street of the tournée for a visiting admin.
  final List<StreetRow> mine;

  /// The other streets of the tournée (« Autres rues de la tournée »), in
  /// French order; none for a visiting admin.
  final List<StreetRow> others;

  /// The streets and house dots the map draws.
  final MapLayers layers;

  /// Where the map shows: first the tournée's streets, else its communes;
  /// null (all of France) when neither has a place on the map. Decided
  /// when the streets are first read, so a street added meanwhile by the
  /// team never moves the map under the member's finger; it moves only to
  /// a street tapped among « Autres rues de la tournée » (#93).
  final GeoBounds? area;

  /// The card of the street tapped on the map or among « Autres rues de
  /// la tournée » (PLAN §5.4): its progress, who covers it, « Ouvrir » and
  /// « Me l'attribuer » or « Ne plus la faire »; null when none is.
  final StreetCardInTournee? card;

  /// The line of the street whose card shows, lit up over the others;
  /// none without a card, or for a street with no line.
  final StreetShape selectedRoad;

  /// The tournée has no street yet.
  bool get hasNoStreet => !loading && mine.isEmpty && others.isEmpty;
}
