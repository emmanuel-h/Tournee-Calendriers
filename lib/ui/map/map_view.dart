import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/ui/map/sector_map.dart';
import 'package:tournee_calendriers/ui/map/street_part_map.dart';

/// How a screen shows its [SectorMap]: as it is, in the app.
///
/// A MapLibre map is a native view, which cannot run in a widget test.
/// Screens put their map through this provider, so a widget test can
/// override it with a stand-in that reads the map's layers and calls its
/// `onStreetTapped`, while the screen around it runs for real.
final sectorMapViewProvider = Provider<Widget Function(SectorMap map)>(
  (ref) =>
      (map) => map,
);

/// How « Partie de la rue » shows its [StreetPartMap], as
/// [sectorMapViewProvider] does for the secteur's map: a widget test
/// overrides it with a stand-in that moves the marks through the map's
/// `onMarkMoved`.
final streetPartMapViewProvider = Provider<Widget Function(StreetPartMap map)>(
  (ref) =>
      (map) => map,
);
