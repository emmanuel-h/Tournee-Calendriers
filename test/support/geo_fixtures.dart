// Points for the geometry tests. Every place is in Villefranche-sur-Saône
// (INSEE 69264), the only real place tests may name.
import 'package:tournee_calendriers/domain/shared/geo_point.dart';

import 'results.dart';

/// A point the test knows is valid: `at(45.98915, 4.71862)`.
GeoPoint at(double latitude, double longitude) =>
    valueOf(GeoPoint.create(latitude: latitude, longitude: longitude));
