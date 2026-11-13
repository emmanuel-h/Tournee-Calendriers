import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/geometry/join_lines.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/infrastructure/geopf/mappers/bdtopo_roads_mapper.dart';
import 'package:tournee_calendriers/infrastructure/http/app_user_agent.dart';
import 'package:tournee_calendriers/infrastructure/http/capped_get.dart';
import 'package:tournee_calendriers/infrastructure/http/no_network.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/roads_by_name.dart';

/// The [StreetShapes] read from IGN BD TOPO (PLAN §5.18, §9): the road
/// stretches of the Géoplateforme WFS (`BDTOPO_V3:troncon_de_route`), each
/// with the BAN id of the street on each side. A street's line is found by
/// its BAN id, never by its name; [RoadsByName] (the map's own roads, from
/// OpenStreetMap) is asked only when BD TOPO has no stretch of the street.
/// Free, no key, Licence Ouverte 2.0 (credited « IGN (BD TOPO) »).
///
/// Like `BanAddressDirectory`, this class only does the transport (URL,
/// headers, timeout, status code) and turns every way it can go wrong into
/// a [StreetShapesFailure]; reading the GeoJSON is `banRoadsFromJson`'s job.
final class IgnStreetShapes implements StreetShapes {
  /// [client] is given so tests can pass a `MockClient` and the composition
  /// root shares one client across services; [byName] is the fallback.
  IgnStreetShapes(
    http.Client client, {
    required this.byName,
    this.timeout = defaultTimeout,
    this.maxAnswerBytes = defaultMaxAnswerBytes,
  }) : _client = client;

  /// The same wait as the BAN's (`BanAddressDirectory`): an answer takes a
  /// fifth of a second; beyond this, the user is better told there is no
  /// network.
  static const defaultTimeout = Duration(seconds: 15);

  /// The longest answer read: 1000 stretches are about 600 kB.
  static const defaultMaxAnswerBytes = 8 << 20;

  /// The most stretches asked in one answer (`COUNT`). An area holding
  /// more ([StreetShapesFailure.tooLarge]) is several hundred streets.
  static const maxStretches = 1000;

  /// How far around the street's houses its stretches are looked for. The
  /// WFS takes 16 to 20 s to filter all of France by a BAN id (no index on
  /// it), but a fifth of a second within a box, even 20 km across: the
  /// box only keeps the search fast, a street's road running at most a
  /// little past its last houses.
  static const idSearchMarginMetres = 2000.0;

  /// Two stretches whose ends are this close are one line: BD TOPO cuts a
  /// road at each crossing, ends on the same point.
  static const joinToleranceMetres = 1.0;

  static final _wfs = Uri.https('data.geopf.fr', '/wfs/ows');

  /// Read for each stretch: the BAN street, its name and commune on each
  /// side, the road's own names, and its line. Nothing else is sent.
  static const _properties = [
    'identifiant_voie_ban_gauche',
    'identifiant_voie_ban_droite',
    'nom_voie_ban_gauche',
    'nom_voie_ban_droite',
    'insee_commune_gauche',
    'insee_commune_droite',
    'nom_collaboratif_gauche',
    'nom_collaboratif_droite',
    'geometrie',
  ];

  /// The coordinates of a `BBOX`: EPSG:4326 as its URN orders it,
  /// latitude first.
  static const _crs = 'urn:ogc:def:crs:EPSG::4326';

  final http.Client _client;

  /// The map's roads by name: the fallback.
  final RoadsByName byName;

  /// How long each request waits for its answer before giving up.
  final Duration timeout;

  /// How many bytes of an answer are read at most.
  final int maxAnswerBytes;

  @override
  Future<Result<StreetShape, StreetShapesFailure>> shapeOf({
    required BanStreetId? banId,
    required StreetName name,
    required GeoBounds area,
  }) async {
    if (banId != null) {
      final id = _quoted(banId.value);
      final box = _box(area.expandedBy(idSearchMarginMetres));
      switch (await _stretches({
        'CQL_FILTER':
            "BBOX(geometrie,$box,'$_crs') AND "
            '(identifiant_voie_ban_gauche=$id OR '
            'identifiant_voie_ban_droite=$id)',
      })) {
        // BD TOPO down: no line now rather than the map's by name, which
        // would be stored for good. The street is asked again later.
        case Err(:final failure):
          return Err(failure);
        case Ok(value: BdTopoRoads(:final roads)):
          final lines = [
            for (final road in roads)
              if (road.banId == banId) ...road.shape.lines,
          ];
          if (lines.isNotEmpty) {
            return Ok(
              StreetShape(
                joinLines(lines, toleranceMetres: joinToleranceMetres),
              ),
            );
          }
      }
    }
    // A street IGN has not mapped yet, or one without BAN id.
    return byName.shapeOf(name: name, area: area);
  }

  @override
  Future<Result<List<BanRoad>, StreetShapesFailure>> roadsIn(
    GeoBounds area,
  ) async => switch (await _stretches({'BBOX': '${_box(area)},$_crs'})) {
    Err(:final failure) => Err(failure),
    Ok(value: BdTopoRoads(:final matched)) when matched > maxStretches =>
      const Err(StreetShapesFailure.tooLarge),
    Ok(value: BdTopoRoads(:final roads)) => Ok(roads),
  };

  @override
  Future<Result<List<NamedRoad>, StreetShapesFailure>> namedRoadsIn(
    GeoBounds area,
  ) => byName.roadsIn(area);

  /// The stretches the WFS gives for [filter] (a `BBOX`, or a
  /// `CQL_FILTER`), at most [maxStretches].
  Future<Result<BdTopoRoads, StreetShapesFailure>> _stretches(
    Map<String, String> filter,
  ) async {
    final url = _wfs.replace(
      queryParameters: {
        'SERVICE': 'WFS',
        'VERSION': '2.0.0',
        'REQUEST': 'GetFeature',
        'TYPENAMES': 'BDTOPO_V3:troncon_de_route',
        'OUTPUTFORMAT': 'application/json',
        'SRSNAME': 'EPSG:4326',
        'PROPERTYNAME': _properties.join(','),
        'COUNT': '$maxStretches',
        ...filter,
      },
    );
    final http.Response response;
    try {
      response = await cappedGet(
        _client,
        url,
        headers: {'User-Agent': appUserAgent, 'Accept': 'application/json'},
        maxBytes: maxAnswerBytes,
      ).timeout(timeout);
    } on ResponseTooLarge {
      return const Err(StreetShapesFailure.serviceError);
    } on TimeoutException {
      return const Err(StreetShapesFailure.noNetwork);
    } on http.ClientException catch (error) {
      // What `http` throws when the connection fails (it wraps the socket
      // error).
      return Err(_transportFailure(error));
    } on IOException catch (error) {
      // A socket or TLS error that reached us unwrapped.
      return Err(_transportFailure(error));
    }
    if (response.statusCode != HttpStatus.ok) {
      return const Err(StreetShapesFailure.serviceError);
    }
    try {
      // Decoded from the bytes: the service sends UTF-8 (« Allée »),
      // whatever its headers say.
      return Ok(banRoadsFromJson(jsonDecode(utf8.decode(response.bodyBytes))));
    } on FormatException {
      // Not UTF-8, not JSON (the WFS answers a refused filter in XML), or
      // not a collection of stretches.
      return const Err(StreetShapesFailure.serviceError);
    }
  }

  /// The four sides of [area], latitude first, to the 7th decimal (about a
  /// centimetre): never written with an exponent, which the WFS may refuse.
  static String _box(GeoBounds area) => [
    area.south,
    area.west,
    area.north,
    area.east,
  ].map((degrees) => degrees.toStringAsFixed(7)).join(',');

  /// [text] as a CQL text: between quotes, each quote in it doubled, so an
  /// id cannot end the filter early.
  static String _quoted(String text) => "'${text.replaceAll("'", "''")}'";
}

/// No network only when the phone found no way out; a service that refused
/// or cut the connection is a service error (#137).
StreetShapesFailure _transportFailure(Object error) => meansNoNetwork(error)
    ? StreetShapesFailure.noNetwork
    : StreetShapesFailure.serviceError;
