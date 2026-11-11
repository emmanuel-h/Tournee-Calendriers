// Translation between the offline map of the app (`OfflineMapStore`) and
// the map library's offline regions. Pure functions: no platform call
// here, so they are tested alone.
//
// A region's metadata names the secteur it was made for:
//
//   { tournee: "t49" }
//
// so the regions of one secteur can be found among those of the phone.
// `hide Error`: the map library has a class `Error` (a failed download)
// that would hide Dart's own here.
import 'package:maplibre_gl/maplibre_gl.dart' hide Error;
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/offline_area.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

/// The key of the sector's id in a region's metadata. It keeps the name it
/// had before the code said « sector » (#116): the regions already on a
/// phone are found by it, so renaming it would orphan their offline map.
const sectorMetadataKey = 'tournee';

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

/// The metadata of a region made for [sector].
Map<String, dynamic> regionMetadata(SectorId sector) => {
  sectorMetadataKey: sector.value,
};

/// The region of the app [region] is; null when it was not made for a
/// secteur (no or another metadata) or its bounds are not a place (the
/// map library hands bounds over the antimeridian west of east).
OfflineMapRegion? offlineMapRegionOf(OfflineRegion region) {
  final sector = region.metadata[sectorMetadataKey];
  if (sector is! String || sector.trim().isEmpty) return null;
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
    sector: SectorId(sector),
    bounds: bounds,
  );
}

/// The progress of the app for the map library's [status]: its progress
/// is a percentage.
MapDownloadProgress progressOf(InProgress status) => MapDownloadProgress(
  fraction: (status.progress / 100).clamp(0.0, 1.0),
  bytes: status.completedResourceSize,
);
