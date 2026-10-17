import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/street/progress_level.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/ui/map/map_style.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

void main() {
  group('streetLineColor', () {
    test('should colour each level with its map token', () {
      const colors = AppColors.light;

      expect(streetLineColor(ProgressLevel.done, colors), colors.mapStreetDone);
      expect(
        streetLineColor(ProgressLevel.partial, colors),
        colors.mapStreetPartial,
      );
      expect(streetLineColor(ProgressLevel.toDo, colors), colors.mapStreetToDo);
      expect(streetLineColor(ProgressLevel.free, colors), colors.mapStreetFree);
    });
  });

  group('tappedStreet', () {
    test('should name the street when a solid street line is tapped', () {
      expect(
        tappedStreet(MapIds.streetLines, 'rue-nationale'),
        StreetId('rue-nationale'),
      );
    });

    test('should name the street when a « libre » line is tapped', () {
      expect(
        tappedStreet(MapIds.freeStreetLines, 'rue-de-la-paix'),
        StreetId('rue-de-la-paix'),
      );
    });

    test('should name the street when the line under « libre » is tapped', () {
      expect(
        tappedStreet(MapIds.freeStreetBase, 'rue-de-la-paix'),
        StreetId('rue-de-la-paix'),
      );
    });

    test('should name the street when one of its house dots is tapped', () {
      expect(
        tappedStreet(MapIds.houseDots, 'rue-nationale'),
        StreetId('rue-nationale'),
      );
    });

    test('should name nothing when the picked road is tapped', () {
      expect(tappedStreet(MapIds.selectedCasing, 'selected'), isNull);
      expect(tappedStreet(MapIds.selectedCore, 'selected'), isNull);
    });

    test('should name nothing when a layer of the style is tapped', () {
      expect(tappedStreet('highway-name-minor', '42'), isNull);
    });
  });

  group('lineLayersBelow', () {
    test('should draw the lines under the labels when the style has them', () {
      expect(
        lineLayersBelow(['background', 'road_minor', 'waterway_line_label']),
        'waterway_line_label',
      );
    });

    test('should draw the lines on top when the style has no such layer', () {
      expect(lineLayersBelow(['background', 'road_minor']), isNull);
    });
  });

  group('houseDotImage', () {
    test('should name one picture per status', () {
      expect(HouseDotStatus.values.map(houseDotImage), [
        'tc-house-toDo',
        'tc-house-done',
        'tc-house-nobodyHome',
        'tc-house-comeBack',
        'tc-house-partial',
      ]);
    });
  });

  group('tourneeMapLayers', () {
    final layers = tourneeMapLayers(AppColors.light);
    MapLayerSpec layer(String id) => layers.singleWhere((l) => l.id == id);
    Map<String, dynamic> json(String id) => layer(id).properties.toJson();

    test('should stack streets, then the picked road, then the dots', () {
      expect(layers.map((l) => l.id), [
        MapIds.streetLines,
        MapIds.freeStreetBase,
        MapIds.freeStreetLines,
        MapIds.selectedCasing,
        MapIds.selectedCore,
        MapIds.selectedPointHalo,
        MapIds.selectedPointDot,
        MapIds.houseDots,
      ]);
      expect(layers.map((l) => l.source), [
        MapIds.streetsSource,
        MapIds.streetsSource,
        MapIds.streetsSource,
        MapIds.selectedSource,
        MapIds.selectedSource,
        MapIds.selectedPointSource,
        MapIds.selectedPointSource,
        MapIds.housesSource,
      ]);
    });

    test('should draw only the street lines under the labels', () {
      expect(layers.map((l) => l.belowLabels), [
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
      ]);
    });

    test('should answer taps on streets and dots, not on the picked road', () {
      expect(layers.map((l) => l.interactive), [
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        true,
      ]);
    });

    test('should show the dots from street zoom only', () {
      expect(layer(MapIds.houseDots).minZoom, 16);
      expect(layers.where((l) => l.minZoom != null), hasLength(1));
    });

    test('should split the « libre » streets into their own layer', () {
      expect(layer(MapIds.streetLines).filter, [
        '!',
        [
          '==',
          ['get', 'level'],
          'free',
        ],
      ]);
      for (final id in [MapIds.freeStreetBase, MapIds.freeStreetLines]) {
        expect(layer(id).filter, [
          '==',
          ['get', 'level'],
          'free',
        ]);
      }
      expect(layers.where((l) => l.filter != null), hasLength(3));
    });

    test('should colour each street line by its level with the map tokens', () {
      const byLevel = [
        'match',
        ['get', 'level'],
        'free',
        '#6b7078',
        'toDo',
        '#2f5da8',
        'partial',
        '#e0a21b',
        'done',
        '#1e6b47',
        '#6b7078',
      ];
      expect(json(MapIds.streetLines)['line-color'], byLevel);
      expect(json(MapIds.freeStreetBase)['line-color'], byLevel);
      expect(json(MapIds.freeStreetLines)['line-color'], byLevel);
    });

    test('should draw a faint solid line under the « libre » dashes', () {
      expect(json(MapIds.freeStreetBase), {
        'line-color': isA<List<Object>>(),
        'line-width': [
          'interpolate',
          ['linear'],
          ['zoom'],
          12,
          2.5,
          16,
          5,
          19,
          9,
        ],
        'line-opacity': 0.35,
        'line-cap': 'round',
        'line-join': 'round',
      });
    });

    test('should draw solid round lines that widen with the zoom', () {
      expect(json(MapIds.streetLines), {
        'line-color': isA<List<Object>>(),
        'line-width': [
          'interpolate',
          ['linear'],
          ['zoom'],
          12,
          3,
          16,
          7,
          19,
          12,
        ],
        'line-cap': 'round',
        'line-join': 'round',
      });
    });

    test('should dash the « libre » lines, thinner', () {
      expect(json(MapIds.freeStreetLines), {
        'line-color': isA<List<Object>>(),
        'line-width': [
          'interpolate',
          ['linear'],
          ['zoom'],
          12,
          2.5,
          16,
          5,
          19,
          9,
        ],
        'line-dasharray': [2, 1.6],
        'line-join': 'round',
      });
    });

    test('should draw the picked road as a dark casing with a white core', () {
      expect(json(MapIds.selectedCasing), {
        'line-color': '#1b1f24',
        'line-width': [
          'interpolate',
          ['linear'],
          ['zoom'],
          12,
          8,
          16,
          16,
          19,
          24,
        ],
        'line-cap': 'round',
        'line-join': 'round',
      });
      expect(json(MapIds.selectedCore), {
        'line-color': '#ffffff',
        'line-width': [
          'interpolate',
          ['linear'],
          ['zoom'],
          12,
          3,
          16,
          6,
          19,
          10,
        ],
        'line-cap': 'round',
        'line-join': 'round',
      });
    });

    test('should mark the point tapped as a dark dot in a faint halo', () {
      expect(json(MapIds.selectedPointHalo), {
        'circle-radius': 18,
        'circle-color': '#1b1f24',
        'circle-opacity': 0.12,
      });
      expect(json(MapIds.selectedPointDot), {
        'circle-radius': 6,
        'circle-color': '#1b1f24',
      });
    });

    test('should take the picked road colours from the palette', () {
      final dark = tourneeMapLayers(AppColors.dark);
      final casing = dark.singleWhere((l) => l.id == MapIds.selectedCasing);
      final core = dark.singleWhere((l) => l.id == MapIds.selectedCore);

      final point = dark.singleWhere((l) => l.id == MapIds.selectedPointDot);
      expect(point.properties.toJson()['circle-color'], '#ffffff');
      expect(casing.properties.toJson()['line-color'], '#ffffff');
      expect(core.properties.toJson()['line-color'], '#1b1f24');
    });

    test(
      'should show each dot with the picture of its status and its number',
      () {
        expect(json(MapIds.houseDots), {
          'icon-image': [
            'match',
            ['get', 'status'],
            'toDo',
            'tc-house-toDo',
            'done',
            'tc-house-done',
            'nobodyHome',
            'tc-house-nobodyHome',
            'comeBack',
            'tc-house-comeBack',
            'partial',
            'tc-house-partial',
            'tc-house-toDo',
          ],
          'icon-size': [
            'interpolate',
            ['linear'],
            ['zoom'],
            16,
            0.6,
            18,
            1,
          ],
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
          'text-field': ['get', 'number'],
          'text-font': ['Noto Sans Bold'],
          'text-size': 12,
          'text-anchor': 'top',
          'text-offset': [0, 1.3],
          'text-color': '#1b1f24',
          'text-halo-color': '#ffffff',
          'text-halo-width': 1.5,
          'text-optional': true,
        });
      },
    );

    test('should build line and symbol layers', () {
      expect(layer(MapIds.streetLines).properties, isA<LineLayerProperties>());
      expect(layer(MapIds.houseDots).properties, isA<SymbolLayerProperties>());
    });
  });
}
