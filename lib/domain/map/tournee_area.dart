import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/street/street.dart';

/// The margin around a tournée's streets, in metres: the map downloaded for
/// offline use reaches that far beyond them (PLAN §7), so a team member
/// walking a little past the last house still sees where they are.
const tourneeMarginMetres = 300.0;

/// The area of a tournée on the map: every point of its streets' shapes
/// and every house position, plus [tourneeMarginMetres] on each side. Null
/// when none of the [streets] has a place on the map (all typed in by
/// hand, or no street yet).
///
/// Streets in the Corbeille count: one may be restored offline, and its
/// map must be there.
GeoBounds? tourneeArea(Iterable<Street> streets) => GeoBounds.around([
  for (final street in streets) ...[
    ...street.shape.points,
    // `?` before an element adds it only when it is not null: a house
    // typed in by hand has no position.
    for (final house in street.houses) ?house.position,
  ],
])?.expandedBy(tourneeMarginMetres);
