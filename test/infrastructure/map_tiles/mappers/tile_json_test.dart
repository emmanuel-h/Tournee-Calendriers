import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/tile_grid.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/tile_json.dart';

const _template =
    'https://tiles.openfreemap.org/planet/20261011_080001_pt/{z}/{x}/{y}.pbf';

void main() {
  group('tileTemplateFromJson', () {
    test('should read the first address of the tiles', () {
      expect(
        tileTemplateFromJson({
          'tilejson': '3.0.0',
          'tiles': [_template, 'https://elsewhere/{z}/{x}/{y}.pbf'],
          'maxzoom': 14,
        }),
        _template,
      );
    });

    test('should refuse a TileJSON without tiles', () {
      expect(
        () => tileTemplateFromJson({'tilejson': '3.0.0'}),
        throwsFormatException,
      );
      expect(
        () => tileTemplateFromJson({'tiles': <Object>[]}),
        throwsFormatException,
      );
      expect(() => tileTemplateFromJson([_template]), throwsFormatException);
    });

    test('should refuse an address that is not a text', () {
      expect(
        () => tileTemplateFromJson({
          'tiles': [14],
        }),
        throwsFormatException,
      );
    });

    test('should refuse an address without its zoom, column or row', () {
      for (final missing in ['{z}', '{x}', '{y}']) {
        expect(
          () => tileTemplateFromJson({
            'tiles': [_template.replaceAll(missing, '0')],
          }),
          throwsFormatException,
          reason: missing,
        );
      }
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
