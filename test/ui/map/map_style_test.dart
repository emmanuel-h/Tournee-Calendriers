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
    });
  });

  group('tappedStreet', () {
    test('should name the street when a solid street line is tapped', () {
      expect(
        tappedStreet(MapIds.streetLines, 'rue-nationale'),
        StreetId('rue-nationale'),
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

    test('should name nothing when a ticked road is tapped', () {
      expect(tappedStreet(MapIds.pickedTicks, '69264_1460'), isNull);
      expect(tappedStreet(MapIds.pickedCasing, '69264_1460'), isNull);
      expect(tappedStreet(MapIds.pickedMarks, '69264_1460'), isNull);
    });
  });

  group('tappedPick', () {
    test('should name the street when a ticked road is tapped', () {
      expect(
        tappedPick(MapIds.pickedCasing, '69264_1460'),
        BanStreetId('69264_1460'),
      );
    });

    test('should name the street when its ✓ is tapped', () {
      expect(
        tappedPick(MapIds.pickedMarks, '69264_1460'),
        BanStreetId('69264_1460'),
      );
    });

    test('should name nothing for the other layers', () {
      expect(tappedPick(MapIds.streetLines, 'rue-nationale'), isNull);
      expect(tappedPick(MapIds.pickedTicks, '69264_1460'), isNull);
      expect(tappedPick(MapIds.selectedCasing, 'selected'), isNull);
      expect(tappedPick('highway-name-minor', '42'), isNull);
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
        'tc-house-refused',
        'tc-house-nobodyHome',
        'tc-house-comeBack',
        'tc-house-partial',
      ]);
    });
  });

  group('sectorMapLayers', () {
    final layers = sectorMapLayers(AppColors.light);
    MapLayerSpec layer(String id) => layers.singleWhere((l) => l.id == id);
    Map<String, dynamic> json(String id) => layer(id).properties.toJson();

    test('should stack streets, the picked and ticked roads, the point, '
        'the dots, then the ✓ of the ticked roads', () {
      expect(layers.map((l) => l.id), [
        MapIds.streetLines,
        MapIds.selectedCasing,
        MapIds.selectedCore,
        MapIds.pickedCasing,
        MapIds.pickedCore,
        MapIds.selectedPointHalo,
        MapIds.selectedPointDot,
        MapIds.houseDots,
        MapIds.pickedMarks,
        MapIds.pickedTicks,
      ]);
      expect(layers.map((l) => l.source), [
        MapIds.streetsSource,
        MapIds.selectedSource,
        MapIds.selectedSource,
        MapIds.pickedSource,
        MapIds.pickedSource,
        MapIds.selectedPointSource,
        MapIds.selectedPointSource,
        MapIds.housesSource,
        MapIds.pickedMarksSource,
        MapIds.pickedMarksSource,
      ]);
    });

    test('should draw only the street lines under the labels', () {
      expect(layers.map((l) => l.belowLabels), [
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
      ]);
    });

    test('should answer taps on streets, dots, ticked roads and their ✓, '
        'not on the picked road', () {
      expect(layers.map((l) => l.interactive), [
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        false,
      ]);
    });

    test('should show the dots from street zoom only', () {
      expect(layer(MapIds.houseDots).minZoom, 16);
      expect(layers.where((l) => l.minZoom != null), hasLength(1));
    });

    test('should draw every street in one layer, with no filter (PLAN '
        '§5.14)', () {
      expect(layers.where((l) => l.filter != null), isEmpty);
    });

    test('should colour each street line by its level with the map tokens', () {
      expect(json(MapIds.streetLines)['line-color'], [
        'match',
        ['get', 'level'],
        'toDo',
        '#2f5da8',
        'partial',
        '#e0a21b',
        'done',
        '#1e6b47',
        '#2f5da8',
      ]);
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

    test('should draw a ticked road as the picked one', () {
      expect(json(MapIds.pickedCasing), json(MapIds.selectedCasing));
      expect(json(MapIds.pickedCore), json(MapIds.selectedCore));
    });

    test('should draw the ✓ of every ticked road as a dark disc that every '
        'renderer shows, and its picture over it, even over a label', () {
      expect(json(MapIds.pickedMarks), {
        'circle-radius': 15.0,
        'circle-color': '#1b1f24',
      });
      expect(json(MapIds.pickedTicks), {
        'icon-image': 'tc-picked-mark',
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
      });
    });

    test('should keep the layer ids apart from the source ids', () {
      final sources = layers.map((l) => l.source).toSet();

      expect(layers.where((l) => sources.contains(l.id)), isEmpty);
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

    test('should keep the light picked road colours when the palette is '
        'dark', () {
      // The base map stays light in dark mode (T5.1): a dark casing with a
      // white core still stands out on it.
      final dark = sectorMapLayers(AppColors.dark);
      final casing = dark.singleWhere((l) => l.id == MapIds.selectedCasing);
      final core = dark.singleWhere((l) => l.id == MapIds.selectedCore);

      final point = dark.singleWhere((l) => l.id == MapIds.selectedPointDot);
      expect(point.properties.toJson()['circle-color'], '#1b1f24');
      expect(casing.properties.toJson()['line-color'], '#1b1f24');
      expect(core.properties.toJson()['line-color'], '#ffffff');
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
            'refused',
            'tc-house-refused',
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
