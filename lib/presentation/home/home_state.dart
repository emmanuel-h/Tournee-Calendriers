import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/home/street_row.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';

/// What Accueil shows (PLAN §5.3, §5.14, RunStart and HomeZoom mockups):
/// the map of the secteur and its « Rues » panel. Immutable: the notifier
/// replaces it as a whole, and the screen redraws.
final class HomeState {
  HomeState({
    required this.loading,
    required this.done,
    required this.total,
    required List<StreetRow> streets,
    required this.layers,
    required this.area,
    required this.card,
    required this.selectedRoad,
  }) : streets = List.unmodifiable(streets);

  /// True until the streets have been read once.
  final bool loading;

  /// The doors visited (done or refused) of every street of the secteur,
  /// out of [total] (« Rues · 31/50 »).
  final int done;
  final int total;

  /// Every street of the secteur, in French order: each member covers them
  /// all (PLAN §5.14).
  final List<StreetRow> streets;

  /// The streets and house dots the map draws.
  final MapLayers layers;

  /// Where the map shows: first the secteur's streets, else its communes;
  /// null (all of France) when neither has a place on the map. Decided
  /// when the streets are first read, so a street added meanwhile by the
  /// team never moves the map under the member's finger.
  final GeoBounds? area;

  /// The card of the street tapped on the map (PLAN §5.14): its progress
  /// and « Ouvrir »; null when none is.
  final StreetCardInSector? card;

  /// The line of the street whose card shows, lit up over the others;
  /// none without a card, or for a street with no line.
  final StreetShape selectedRoad;

  /// The secteur has no street yet.
  bool get hasNoStreet => !loading && streets.isEmpty;
}
