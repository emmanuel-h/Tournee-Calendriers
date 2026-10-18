import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_commune.dart';

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

/// The margin around a commune's centre, in metres: a commune of a few
/// thousand people spreads over 1 to 3 km around its town hall, so the
/// map of « Ajouter des rues » shows most of it at once.
const communeMarginMetres = 2000.0;

/// The area around the [communes]' centres, plus [communeMarginMetres] on
/// each side; null when none has a centre (none given by the service, or
/// a tournée created before the communes).
GeoBounds? communesArea(Iterable<TourneeCommune> communes) =>
    GeoBounds.around([for (final commune in communes) ?commune.centre])
        ?.expandedBy(communeMarginMetres);

/// Where the map of « Ajouter des rues » starts (PLAN §5.4): on the
/// tournée's [communes], where the streets to add are; on its [streets]
/// when no commune has a centre; null (all of France) when neither has a
/// place on the map.
GeoBounds? addStreetsArea(
  Iterable<TourneeCommune> communes,
  Iterable<Street> streets,
) => communesArea(communes) ?? tourneeArea(streets);

/// Where Accueil's map starts (PLAN §5.3): on the tournée's [streets],
/// where the team walks; on its [communes] while no street has a place on
/// the map (none added yet, or all typed in by hand); null (all of France)
/// when neither has one.
GeoBounds? homeArea(
  Iterable<TourneeCommune> communes,
  Iterable<Street> streets,
) => tourneeArea(streets) ?? communesArea(communes);

/// How far beyond a street's houses its road is looked for on the map, in
/// metres: the road runs a little past the last numbers, while a road of
/// the same name in the next commune is much farther.
const shapeSearchMarginMetres = 150.0;

/// Where to look for the road of a street whose houses stand at
/// [positions] (PLAN §9): around them, plus [shapeSearchMarginMetres] on
/// each side; null without any position (a street typed in by hand).
GeoBounds? shapeSearchArea(Iterable<GeoPoint> positions) =>
    GeoBounds.around(positions)?.expandedBy(shapeSearchMarginMetres);

/// The margin around a street shown on Accueil's map, in metres: enough
/// to see the crossroads at both ends, close enough to read the houses.
const streetMarginMetres = 60.0;

/// Where Accueil's map goes to show [street] (PLAN §5.3, #93): its line on
/// the map, else its houses' positions while it has no line, plus
/// [streetMarginMetres] on each side; null when it has neither (typed in
/// by hand).
GeoBounds? streetArea(Street street) => GeoBounds.around(
  street.shape.isEmpty
      ? [for (final house in street.houses) ?house.position]
      : street.shape.points,
)?.expandedBy(streetMarginMetres);
