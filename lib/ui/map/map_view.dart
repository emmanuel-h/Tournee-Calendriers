import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/ui/map/tournee_map.dart';

/// How a screen shows its [TourneeMap]: as it is, in the app.
///
/// A MapLibre map is a native view, which cannot run in a widget test.
/// Screens put their map through this provider, so a widget test can
/// override it with a stand-in that reads the map's layers and calls its
/// `onStreetTapped`, while the screen around it runs for real.
final tourneeMapViewProvider = Provider<Widget Function(TourneeMap map)>(
  (ref) =>
      (map) => map,
);
