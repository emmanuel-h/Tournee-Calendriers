import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/map/house_dot_image.dart';
import 'package:tournee_calendriers/ui/map/map_camera.dart';
import 'package:tournee_calendriers/ui/map/map_geojson.dart';
import 'package:tournee_calendriers/ui/map/map_style.dart';
import 'package:tournee_calendriers/ui/map/part_marks.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// The map of « Partie de la rue » (PLAN §5.15, StreetPart mockup): the
/// street on the OpenFreeMap background, its road grey with the stretch
/// kept as the selected road, the other secteurs' stretches hatched, its
/// house dots, and the two marks ([PartMarks]) the finger drags along the
/// road.
///
/// The map stays where it opens, fitted to the street: a drag on it moves
/// a mark, never the map, so the places the marks snap to are measured on
/// screen once (each time the side shown changes) and a drag needs no call
/// to the map. Thin MapLibre glue, covered by the device checklist (PLAN
/// §11): what it draws is decided by the domain ([PartDrawing]), and turned
/// into sources and layers by `map_geojson.dart` and `map_style.dart`.
final class StreetPartMap extends StatefulWidget {
  const StreetPartMap({
    super.key,
    required this.drawing,
    required this.onMarkMoved,
  });

  final PartDrawing drawing;

  /// A mark dragged to the place [gap] of [PartDrawing.gaps].
  final void Function(PartMark mark, int gap) onMarkMoved;

  @override
  State<StreetPartMap> createState() => _StreetPartMapState();
}

final class _StreetPartMapState extends State<StreetPartMap> {
  MapLibreMapController? _controller;
  var _styleReady = false;

  /// What the map shows now, to send only what changed.
  StreetShape? _shownRoad;
  StreetShape? _shownKept;
  List<PartDot>? _shownDots;
  List<OtherStretch>? _shownOthers;

  /// The places of the marks on screen, in logical pixels, and the places
  /// they were measured for.
  List<Offset>? _places;
  List<GeoPoint>? _placesFor;

  @override
  void didUpdateWidget(StreetPartMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_sync());
  }

  void _onMapCreated(MapLibreMapController controller) =>
      _controller = controller;

  /// Adds our sources and layers once the style is loaded; the screen may
  /// have closed meanwhile (see `SectorMap`).
  Future<void> _onStyleLoaded() async {
    try {
      await _addOurLayers();
    } on MissingPluginException {
      if (mounted) rethrow;
    } on PlatformException {
      if (mounted) rethrow;
    }
  }

  Future<void> _addOurLayers() async {
    if (!mounted) return;
    final controller = _controller!;
    final colors = AppColors.of(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final drawing = widget.drawing;
    await controller.addImage(
      partHatchImage,
      await partHatchPng(colors, pixelRatio),
    );
    if (!mounted) return;
    _shownRoad = drawing.road;
    _shownKept = drawing.kept;
    _shownDots = drawing.dots;
    await controller.addGeoJsonSource(
      MapIds.partRoadSource,
      partRoadGeoJson(drawing.road),
    );
    await controller.addGeoJsonSource(
      MapIds.partKeptSource,
      selectedRoadGeoJson(drawing.kept),
    );
    await controller.addGeoJsonSource(
      MapIds.partDotsSource,
      partDotsGeoJson(drawing.dots),
    );
    _shownOthers = drawing.others;
    await controller.addGeoJsonSource(
      MapIds.partOthersSource,
      _othersGeoJson(drawing.others),
    );
    final below = lineLayersBelow(await controller.getLayerIds());
    for (final layer in streetPartMapLayers(colors)) {
      if (!mounted) return;
      await controller.addLayer(
        layer.source,
        layer.id,
        layer.properties,
        belowLayerId: layer.belowLabels ? below : null,
        enableInteraction: layer.interactive,
        filter: layer.filter,
      );
    }
    if (!mounted) return;
    _styleReady = true;
    await _sync();
    // Room above the road for the marks' labels, and on the sides for the
    // marks beyond the first and last dots.
    const side = AppSizes.partMarkLabelWidth / 2;
    await controller.moveCamera(
      CameraUpdate.newLatLngBounds(
        latLngBoundsOf(drawing.area),
        left: side,
        right: side,
        top: AppSizes.partMarkLabelHeight + AppSizes.partMarkStemHeight,
        bottom: AppSizes.minTapTarget,
      ),
    );
  }

  Future<void> _sync() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    final drawing = widget.drawing;
    if (_shownRoad != drawing.road) {
      _shownRoad = drawing.road;
      await controller.setGeoJsonSource(
        MapIds.partRoadSource,
        partRoadGeoJson(drawing.road),
      );
    }
    if (_shownKept != drawing.kept) {
      _shownKept = drawing.kept;
      await controller.setGeoJsonSource(
        MapIds.partKeptSource,
        selectedRoadGeoJson(drawing.kept),
      );
    }
    if (!listEquals(_shownDots, drawing.dots)) {
      _shownDots = drawing.dots;
      await controller.setGeoJsonSource(
        MapIds.partDotsSource,
        partDotsGeoJson(drawing.dots),
      );
    }
    if (!listEquals(_shownOthers, drawing.others)) {
      _shownOthers = drawing.others;
      await controller.setGeoJsonSource(
        MapIds.partOthersSource,
        _othersGeoJson(drawing.others),
      );
    }
    if (!listEquals(_placesFor, drawing.gaps)) await _measure();
  }

  /// The other secteurs' stretches, labelled « Secteur 12 ».
  Map<String, Object> _othersGeoJson(List<OtherStretch> others) =>
      partOthersGeoJson(others, AppLocalizations.of(context).otherSectorLabel);

  /// Measures where the places of the marks are on screen.
  Future<void> _measure() async {
    final controller = _controller;
    if (controller == null || !_styleReady || !mounted) return;
    final gaps = widget.drawing.gaps;
    // Android's map counts physical pixels.
    final scale = defaultTargetPlatform == TargetPlatform.android
        ? MediaQuery.devicePixelRatioOf(context)
        : 1.0;
    final onScreen = gaps.isEmpty
        ? const <Point<num>>[]
        : await controller.toScreenLocationBatch([
            for (final gap in gaps) latLngOf(gap),
          ]);
    // Another side shown since the call left, or the screen closed.
    if (!mounted || !listEquals(widget.drawing.gaps, gaps)) return;
    setState(() {
      _placesFor = gaps;
      _places = [
        for (final point in onScreen) Offset(point.x / scale, point.y / scale),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final places = _places;
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          container: true,
          label: AppLocalizations.of(context).streetPartMap,
          child: MapLibreMap(
            styleString: openFreeMapStyle,
            initialCameraPosition: initialCamera(widget.drawing.area),
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            // Measured again once the camera stops on the street.
            onCameraIdle: () => unawaited(_measure()),
            annotationOrder: const [],
            // The map does not move: a finger on it drags a mark.
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            compassEnabled: false,
          ),
        ),
        if (places != null && listEquals(_placesFor, widget.drawing.gaps))
          PartMarks(
            drawing: widget.drawing,
            places: places,
            onMoved: widget.onMarkMoved,
          ),
      ],
    );
  }
}
