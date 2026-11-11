// A stand-in for the MapLibre map in widget tests, where a native map view
// cannot run (see `sectorMapViewProvider`).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/map/sector_map.dart';
import 'package:tournee_calendriers/ui/map/street_part_map.dart';

/// Takes the room of [map] and draws nothing; a test reads what the
/// screen gave the map (its layers, area, padding) and taps it through
/// [map]'s callbacks.
final class FakeMapView extends StatelessWidget {
  const FakeMapView(this.map, {super.key});

  final SectorMap map;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// The map the screen under test shows now.
SectorMap shownMap(WidgetTester tester) =>
    tester.widget<FakeMapView>(find.byType(FakeMapView)).map;

/// The same stand-in for the map of « Partie de la rue »: a test reads the
/// drawing the screen gave it and moves a mark through its `onMarkMoved`.
final class FakePartMapView extends StatelessWidget {
  const FakePartMapView(this.map, {super.key});

  final StreetPartMap map;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// The map of « Partie de la rue » shown now.
StreetPartMap shownPartMap(WidgetTester tester) =>
    tester.widget<FakePartMapView>(find.byType(FakePartMapView)).map;
