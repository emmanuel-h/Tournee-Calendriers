// A stand-in for the MapLibre map in widget tests, where a native map view
// cannot run (see `tourneeMapViewProvider`).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/map/tournee_map.dart';

/// Takes the room of [map] and draws nothing; a test reads what the
/// screen gave the map (its layers, area, padding) and taps it through
/// [map]'s callbacks.
final class FakeMapView extends StatelessWidget {
  const FakeMapView(this.map, {super.key});

  final TourneeMap map;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// The map the screen under test shows now.
TourneeMap shownMap(WidgetTester tester) =>
    tester.widget<FakeMapView>(find.byType(FakeMapView)).map;
