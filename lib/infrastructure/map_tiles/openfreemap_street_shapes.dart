import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/infrastructure/http/app_user_agent.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/street_lines.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/tile_grid.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/tile_json.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/vector_tile.dart';

/// The [StreetShapes] read from the OpenFreeMap vector tiles (PLAN §9),
/// the same OpenStreetMap data the map draws: the roads of the
/// `transportation_name` layer of the zoom-14 tiles around the street.
/// No key; a tile is about 50 kB and comes in a tenth of a second.
///
/// Like `BanAddressDirectory`, this class only does the transport (and
/// keeps what it read); reading the tiles and drawing the street are the
/// pure functions of `mappers/`.
///
/// What it keeps in memory, for as long as the app runs: the address of
/// the tiles (read from the TileJSON once, forgotten when a tile cannot be
/// read, since a new version of the map may have replaced it) and the
/// roads of the last [tilesKept] tiles read, since the streets of a
/// tournée share a few tiles.
final class OpenFreeMapStreetShapes implements StreetShapes {
  /// [client] is given so tests can pass a `MockClient` and the composition
  /// root shares one client across services.
  OpenFreeMapStreetShapes(
    http.Client client, {
    this.timeout = defaultTimeout,
    this.tilesKept = defaultTilesKept,
  }) : _client = client;

  /// A tile or the TileJSON is small: beyond this, the signal is too weak.
  static const defaultTimeout = Duration(seconds: 10);

  /// About the tiles of a few communes: the roads of a tile weigh a few
  /// tens of kB in memory.
  static const defaultTilesKept = 64;

  /// The most tiles read for one street. A street's houses span a few
  /// hundred metres, one to four tiles of about 1.7 km; more means a number
  /// the BAN puts far away, and the street is given no shape rather than
  /// a download of a whole region.
  static const maxTilesPerStreet = 16;

  /// The zoom of the tiles read: the most detailed OpenFreeMap has.
  static const zoom = 14;

  /// The layer of the named roads, in the OpenMapTiles scheme.
  static const roadsLayer = 'transportation_name';

  static final tileJsonUrl = Uri.https('tiles.openfreemap.org', '/planet');

  final http.Client _client;

  /// How long each request waits for its answer before giving up.
  final Duration timeout;

  /// How many tiles' roads are kept in memory.
  final int tilesKept;

  String? _template;

  /// The roads of the tiles read, oldest first: a Dart map keeps the order
  /// its keys were added in, so the first is the one to drop.
  final _tiles = <TileId, TileLayer>{};

  @override
  Future<Result<StreetShape, StreetShapesFailure>> shapeOf({
    required StreetName name,
    required GeoBounds area,
  }) async {
    final tiles = tilesCovering(area, zoom: zoom);
    if (tiles.length > maxTilesPerStreet) return const Ok(StreetShape.none);
    final read = <(TileId, TileLayer)>[];
    // One tile after the other: a street needs one to four, and a public
    // service is better asked gently.
    for (final tile in tiles) {
      switch (await _roadsOf(tile)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          read.add((tile, value));
      }
    }
    return Ok(streetShapeFromTiles(read, name: name, area: area));
  }

  /// The named roads of [tile], from memory or from the server.
  Future<Result<TileLayer, StreetShapesFailure>> _roadsOf(TileId tile) async {
    if (_tiles[tile] case final kept?) return Ok(kept);
    final String template;
    switch (await _tileTemplate()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        template = value;
    }
    final http.Response response;
    switch (await _get(tileUrl(template, tile))) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        response = value;
    }
    final TileLayer roads;
    if (response.statusCode == HttpStatus.noContent) {
      // A tile with nothing on it (the open sea).
      roads = TileLayer.empty;
    } else if (response.statusCode != HttpStatus.ok) {
      // The version of the map may be gone: read the TileJSON again next
      // time.
      _template = null;
      return const Err(StreetShapesFailure.serviceError);
    } else {
      try {
        roads = namedLinesOf(response.bodyBytes, roadsLayer);
      } on FormatException {
        return const Err(StreetShapesFailure.serviceError);
      }
    }
    if (_tiles.length >= tilesKept) _tiles.remove(_tiles.keys.first);
    _tiles[tile] = roads;
    return Ok(roads);
  }

  /// The address template of the tiles, from memory or from the TileJSON.
  Future<Result<String, StreetShapesFailure>> _tileTemplate() async {
    if (_template case final template?) return Ok(template);
    switch (await _get(tileJsonUrl)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final response):
        if (response.statusCode != HttpStatus.ok) {
          return const Err(StreetShapesFailure.serviceError);
        }
        try {
          final template = tileTemplateFromJson(
            jsonDecode(utf8.decode(response.bodyBytes)),
          );
          _template = template;
          return Ok(template);
        } on FormatException {
          return const Err(StreetShapesFailure.serviceError);
        }
    }
  }

  /// The answer to a GET of [url], or [StreetShapesFailure.noNetwork] when
  /// none came in time.
  Future<Result<http.Response, StreetShapesFailure>> _get(Uri url) async {
    try {
      return Ok(
        await _client
            .get(url, headers: {'User-Agent': appUserAgent})
            .timeout(timeout),
      );
    } on TimeoutException {
      return const Err(StreetShapesFailure.noNetwork);
    } on http.ClientException {
      return const Err(StreetShapesFailure.noNetwork);
    } on IOException {
      return const Err(StreetShapesFailure.noNetwork);
    }
  }
}
