// Where the tiles are: OpenFreeMap describes its tiles in a TileJSON
// document (https://tiles.openfreemap.org/planet) whose `tiles` holds the
// address of each tile, with the version of the map in it
// (`…/planet/20261011_080001_pt/{z}/{x}/{y}.pbf`). The version changes
// each week: it is read, never written in the app. Pure functions.
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/tile_grid.dart';

/// The address template of the tiles in the TileJSON [json] (already
/// decoded from JSON): its first `tiles` entry.
///
/// Throws a [FormatException] when there is none, or when it lacks one of
/// `{z}`, `{x}`, `{y}`.
String tileTemplateFromJson(Object? json) {
  if (json case {'tiles': [final String template, ...]}) {
    if (['{z}', '{x}', '{y}'].every(template.contains)) return template;
  }
  throw const FormatException('No tile address in the TileJSON');
}

/// The address of [tile] in [template].
Uri tileUrl(String template, TileId tile) => Uri.parse(
  template
      .replaceAll('{z}', '${tile.zoom}')
      .replaceAll('{x}', '${tile.x}')
      .replaceAll('{y}', '${tile.y}'),
);
