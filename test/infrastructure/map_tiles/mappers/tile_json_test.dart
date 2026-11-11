import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/tile_grid.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/tile_json.dart';

const _host = 'tiles.openfreemap.org';

const _template =
    'https://tiles.openfreemap.org/planet/20261011_080001_pt/{z}/{x}/{y}.pbf';

void main() {
  group('tileTemplateFromJson', () {
    test('should read the first address of the tiles', () {
      expect(
        tileTemplateFromJson(host: _host, {
          'tilejson': '3.0.0',
          'tiles': [_template, 'https://elsewhere/{z}/{x}/{y}.pbf'],
          'maxzoom': 14,
        }),
        _template,
      );
    });

    test('should refuse a TileJSON without tiles', () {
      expect(
        () => tileTemplateFromJson(host: _host, {'tilejson': '3.0.0'}),
        throwsFormatException,
      );
      expect(
        () => tileTemplateFromJson(host: _host, {'tiles': <Object>[]}),
        throwsFormatException,
      );
      expect(
        () => tileTemplateFromJson(host: _host, [_template]),
        throwsFormatException,
      );
    });

    test('should refuse an address that is not a text', () {
      expect(
        () => tileTemplateFromJson(host: _host, {
          'tiles': [14],
        }),
        throwsFormatException,
      );
    });

    test('should refuse an address without its zoom, column or row', () {
      for (final missing in ['{z}', '{x}', '{y}']) {
        expect(
          () => tileTemplateFromJson(host: _host, {
            'tiles': [_template.replaceAll(missing, '0')],
          }),
          throwsFormatException,
          reason: missing,
        );
      }
    });

    test('should refuse an address that is not https', () {
      for (final scheme in ['http', 'ftp', 'file']) {
        expect(
          () => tileTemplateFromJson(host: _host, {
            'tiles': [_template.replaceFirst('https', scheme)],
          }),
          throwsFormatException,
          reason: scheme,
        );
      }
    });

    test('should refuse an address on another host', () {
      for (final other in [
        'https://elsewhere.example/{z}/{x}/{y}.pbf',
        'https://tiles.openfreemap.org.example/{z}/{x}/{y}.pbf',
        'https://tiles.openfreemap.org@elsewhere.example/{z}/{x}/{y}.pbf',
        'https://sub.tiles.openfreemap.org/{z}/{x}/{y}.pbf',
      ]) {
        expect(
          () => tileTemplateFromJson(host: _host, {
            'tiles': [other],
          }),
          throwsFormatException,
          reason: other,
        );
      }
    });

    test('should refuse an address that is not one', () {
      expect(
        () => tileTemplateFromJson(host: _host, {
          'tiles': ['https://[tiles.openfreemap.org/{z}/{x}/{y}.pbf'],
        }),
        throwsFormatException,
      );
    });

    test('should accept the host whatever its case', () {
      const upper =
          'https://Tiles.OpenFreeMap.org/planet/20261011_080001_pt/{z}/{x}/{y}.pbf';

      expect(
        tileTemplateFromJson(host: _host, {
          'tiles': [upper],
        }),
        upper,
      );
    });
  });

  test('should put the zoom, column and row of a tile in the address', () {
    expect(
      tileUrl(_template, const TileId(zoom: 14, x: 8406, y: 5829)),
      Uri.parse(
        'https://tiles.openfreemap.org/planet/20261011_080001_pt/14/8406/5829.pbf',
      ),
    );
  });
}
