// Translation between the offline map of the app (`OfflineMapStore`) and
// the map library's offline regions. Pure functions: no platform call
// here, so they are tested alone.
//
// A region's metadata names the tournée it was made for:
//
//   { tournee: "t49" }
//
// so the regions of one tournée can be found among those of the phone.
// `hide Error`: the map library has a class `Error` (a failed download)
// that would hide Dart's own here.
import 'package:maplibre_gl/maplibre_gl.dart' hide Error;
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/offline_area.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// The key of the tournée's id in a region's metadata.
const tourneeMetadataKey = 'tournee';

/// The region to download over [bounds] with the map [styleUrl] (the
/// style the map shows: the region is kept under its address), from the
/// lowest to the highest offline zoom.
OfflineRegionDefinition regionDefinition(GeoBounds bounds, String styleUrl) =>
    OfflineRegionDefinition(
      bounds: LatLngBounds(
        southwest: LatLng(bounds.south, bounds.west),
        northeast: LatLng(bounds.north, bounds.east),
      ),
      mapStyleUrl: styleUrl,
      minZoom: offlineMapMinZoom.toDouble(),
      maxZoom: offlineMapMaxZoom.toDouble(),
    );

/// The metadata of a region made for [tournee].
Map<String, dynamic> regionMetadata(TourneeId tournee) => {
  tourneeMetadataKey: tournee.value,
};

/// The region of the app [region] is; null when it was not made for a
/// tournée (no or another metadata) or its bounds are not a place (the
/// map library hands bounds over the antimeridian west of east).
OfflineMapRegion? offlineMapRegionOf(OfflineRegion region) {
  final tournee = region.metadata[tourneeMetadataKey];
  if (tournee is! String || tournee.trim().isEmpty) return null;
  final LatLngBounds(:southwest, :northeast) = region.definition.bounds;
  final bounds = GeoBounds.of(
    south: southwest.latitude,
    west: southwest.longitude,
    north: northeast.latitude,
    east: northeast.longitude,
  );
  if (bounds == null) return null;
  return OfflineMapRegion(
    id: region.id,
    tournee: TourneeId(tournee),
    bounds: bounds,
  );
}

/// The progress of the app for the map library's [status]: its progress
/// is a percentage.
MapDownloadProgress progressOf(InProgress status) => MapDownloadProgress(
  fraction: (status.progress / 100).clamp(0.0, 1.0),
  bytes: status.completedResourceSize,
);
