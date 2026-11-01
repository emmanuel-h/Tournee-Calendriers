// Streets and downloads for the offline tests (PLAN §7), in
// Villefranche-sur-Saône.
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/application/ports/tournee_downloads.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final t49 = TourneeId('t49');
final t12 = TourneeId('t12');

/// A street named [id] with one house at [latitude], [longitude], or none
/// on the map when [latitude] is null.
Street placedStreet(String id, [double? latitude, double longitude = 4.718]) =>
    valueOf(
      Street.create(
        id: StreetId(id),
        name: 'Rue $id',
        commune: villefranche,
        houses: [
          House(
            number: n('1'),
            position: latitude == null ? null : at(latitude, longitude),
          ),
        ],
      ),
    );

final nationale = placedStreet('Nationale', 45.9890);
final paix = placedStreet('Paix', 45.9860);

/// The area kept for [nationale] and [paix].
final area49 = tourneeArea([nationale, paix])!;

/// Another tournée's area, far from [area49].
final area12 = GeoBounds.around([at(45.9700, 4.7000), at(45.9710, 4.7010)])!;

final morning = DateTime.utc(2026, 11, 2, 8, 12);

/// A download of [tournee] made in the [morning], of [area].
TourneeDownload downloadOf(TourneeId tournee, GeoBounds? area) =>
    TourneeDownload(
      tournee: tournee,
      downloadedAt: morning,
      mapBytes: 6600000,
      area: area,
    );

/// A region of the phone.
OfflineMapRegion regionOf(int id, TourneeId tournee, GeoBounds bounds) =>
    OfflineMapRegion(id: id, tournee: tournee, bounds: bounds);
