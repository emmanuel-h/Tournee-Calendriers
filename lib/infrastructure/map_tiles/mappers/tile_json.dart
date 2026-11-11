// Where the tiles are: OpenFreeMap describes its tiles in a TileJSON
// document (https://tiles.openfreemap.org/planet) whose `tiles` holds the
// address of each tile, with the version of the map in it
// (`…/planet/20261011_080001_pt/{z}/{x}/{y}.pbf`). The version changes
// each week: it is read, never written in the app. Pure functions.
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/tile_grid.dart';

/// The address template of the tiles in the TileJSON [json] (already
/// decoded from JSON): its first `tiles` entry.
///
/// The TileJSON comes from the network, so its address is checked before
/// the app asks it for anything: an `https` address on [host], the host the
/// TileJSON itself came from. Since it is parsed here, [tileUrl] cannot
/// fail on a template this function gave.
///
/// Throws a [FormatException] when there is none, when it lacks one of
/// `{z}`, `{x}`, `{y}`, is not an address, is not `https` or is on another
/// host.
String tileTemplateFromJson(Object? json, {required String host}) {
  if (json case {'tiles': [final String template, ...]}) {
    if (['{z}', '{x}', '{y}'].every(template.contains)) {
      // `Uri.parse` throws a FormatException on a text that is not an
      // address; it gives the host in lower case.
      final url = tileUrl(template, const TileId(zoom: 0, x: 0, y: 0));
      if (url.scheme == 'https' && url.host == host) {
        return template;
      }
    }
  }
  throw const FormatException('No usable tile address in the TileJSON');
}

/// The address of [tile] in [template].
Uri tileUrl(String template, TileId tile) => Uri.parse(
  template
      .replaceAll('{z}', '${tile.zoom}')
      .replaceAll('{x}', '${tile.x}')
      .replaceAll('{y}', '${tile.y}'),
);
