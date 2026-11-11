import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/picked_road.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/map/geolocator_phone_location.dart';
import 'package:tournee_calendriers/ui/map/house_dot_image.dart';
import 'package:tournee_calendriers/ui/map/locate_me_button.dart';
import 'package:tournee_calendriers/ui/map/map_camera.dart';
import 'package:tournee_calendriers/ui/map/map_geojson.dart';
import 'package:tournee_calendriers/ui/map/map_style.dart';
import 'package:tournee_calendriers/ui/map/phone_location.dart';
import 'package:tournee_calendriers/ui/map/zone_drawing.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// The map of a secteur (PLAN §5.3, §5.14): the OpenFreeMap background,
/// the streets coloured by progress, the house dots from street zoom, the
/// street picked on Accueil, the roads ticked on « Ajouter des rues », and
/// « Me localiser ».
///
/// It only draws what it is given: what to show is decided by the domain
/// ([MapLayers]) and the screen; this widget turns it into MapLibre
/// sources and layers (`map_geojson.dart`, `map_style.dart`, both tested)
/// and hands taps back as domain values. It is thin MapLibre glue, covered
/// by the device checklist (PLAN §11): a map cannot run in a widget test.
final class SectorMap extends StatefulWidget {
  const SectorMap({
    super.key,
    required this.layers,
    this.selectedRoad = StreetShape.none,
    this.selectedPoint,
    this.pickedRoads = const [],
    this.area,
    this.onStreetTapped,
    this.onPickTapped,
    this.onMapTapped,
    this.onZoomChanged,
    this.zoneMode = false,
    this.zone,
    this.onZoneDrawn,
    this.keepInView,
    this.padding = EdgeInsets.zero,
    this.phoneLocation = const GeolocatorPhoneLocation(),
  });

  /// The streets and houses to draw.
  final MapLayers layers;

  /// The line of the street whose card shows on Accueil, drawn over the
  /// others; none by default.
  final StreetShape selectedRoad;

  /// Where the finger tapped on « Ajouter des rues », marked by a dot while
  /// the street there is looked up; none by default.
  final GeoPoint? selectedPoint;

  /// The roads ticked on « Ajouter des rues », each with its ✓ disc; none
  /// by default.
  final List<PickedRoad> pickedRoads;

  /// The area to show: the map fits it when it opens, and again each time
  /// it changes (another secteur opened, a street found by the search).
  /// Null leaves the camera where the user put it.
  final GeoBounds? area;

  /// A tap on one of the secteur's streets, or on one of its house dots.
  final ValueChanged<StreetId>? onStreetTapped;

  /// A tap on a ticked road, or on its ✓ disc: its BAN street.
  final ValueChanged<BanStreetId>? onPickTapped;

  /// A tap anywhere else on the map: where the finger was.
  final ValueChanged<GeoPoint>? onMapTapped;

  /// The map's zoom level, each time the camera stops after a move (a
  /// pinch, « Me localiser », a fit): Accueil switches its legend at street
  /// zoom.
  final ValueChanged<double>? onZoomChanged;

  /// « Zone » on « Ajouter des rues » (PLAN §5.14): a drag of one finger
  /// draws a rectangle ([onZoneDrawn]) instead of moving the map; two
  /// fingers still move and zoom it.
  final bool zoneMode;

  /// The zone drawn, dimmed around and dashed; none by default.
  final GeoBounds? zone;

  /// A zone drawn with a finger, « Zone » on: its area on the map.
  final ValueChanged<GeoBounds>? onZoneDrawn;

  /// What the map keeps clear of [padding] (#132): when it changes, and
  /// when [padding] grows until the user touches the map, the map slides
  /// just enough to show it, or zooms out if it cannot fit (see
  /// `cameraReveal`). Null leaves the camera alone.
  final GeoBounds? keepInView;

  /// The room other widgets take over the map's edges (a banner on top, a
  /// panel at the bottom): « Me localiser », the attribution and the fitted
  /// area keep clear of it.
  final EdgeInsets padding;

  /// The phone's location, for « Me localiser »; tests give a fake.
  final PhoneLocation phoneLocation;

  @override
  State<SectorMap> createState() => _SectorMapState();
}

final class _SectorMapState extends State<SectorMap> {
  MapLibreMapController? _controller;

  /// Sources and layers can only be added once the style has loaded; until
  /// then the data waits in the widget.
  var _styleReady = false;

  /// What the map shows now, to send only what changed.
  List<StreetLine>? _shownLines;
  List<HouseDot>? _shownDots;
  StreetShape? _shownRoad;
  GeoPoint? _shownPoint;
  List<PickedRoad>? _shownPicks;
  GeoBounds? _shownZone;

  /// Where [SectorMap.zone] is on screen, in logical pixels, so a finger on
  /// its handle resizes it; measured each time it or the camera changes.
  Rect? _zoneOnScreen;

  /// Two fingers are on the map in « Zone » mode: it moves under them
  /// (see [ZoneDrawing]).
  var _twoFingers = false;

  /// The phone's dot shows once « Me localiser » found it: MapLibre then
  /// follows the position itself, with the access already granted.
  var _showPhone = false;

  /// The camera is on its way to a new [SectorMap.area]. Should the room
  /// taken over the map change meanwhile (a street card shown with the
  /// move, measured only once drawn, #93), the area is fitted again, clear
  /// of it. Later, a change of that room (the panel dragged) leaves the
  /// camera where the user put it.
  var _fitting = false;

  /// [SectorMap.keepInView] is to be kept in view: from when it changes
  /// until a finger touches the map (or « Me localiser » moves it). Meanwhile
  /// a panel over the map that grows (a row ticked, the zone's streets
  /// listed, measured only once drawn) moves the map again.
  var _revealing = false;

  @override
  void didUpdateWidget(SectorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `unawaited`: the map updates on its own time; nothing here waits for
    // it, and a build must never wait.
    unawaited(_sync());
    if (widget.area != oldWidget.area ||
        (_fitting && widget.padding != oldWidget.padding)) {
      _fitting = true;
      unawaited(_fit(animate: true));
    }
    if (widget.keepInView != oldWidget.keepInView) {
      _revealing = widget.keepInView != null;
      _revealAfterLayout();
    } else if (_revealing && widget.padding != oldWidget.padding) {
      _revealAfterLayout();
    }
  }

  /// [_reveal] once this frame is laid out: the map's size cannot be read
  /// while widgets are being built, which is when [didUpdateWidget] runs.
  void _revealAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reveal());
    });
  }

  @override
  void dispose() {
    _controller?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onFeatureTapped.add(_onFeatureTapped);
  }

  /// Adds our pictures, sources and layers to the style just loaded.
  ///
  /// The screen may close while they are added (« Ajouter des rues » left
  /// at once, the app restarted): the map's platform side is then gone, and
  /// the call on its way fails with a [MissingPluginException] or a
  /// [PlatformException] (« MAP_NOT_READY »), which mean nothing to a map
  /// no longer shown.
  Future<void> _onStyleLoaded() async {
    try {
      await _addOurLayers();
    } on MissingPluginException {
      if (mounted) rethrow;
    } on PlatformException {
      // « MAP_NOT_READY »: the map view was torn down under the call.
      if (mounted) rethrow;
    }
  }

  Future<void> _addOurLayers() async {
    // The style may finish loading after the map left the screen (the app
    // closed, or another screen took the start's place): nothing to add.
    if (!mounted) return;
    final controller = _controller!;
    // Read before the first `await`: the context must not be used across
    // asynchronous gaps, the widget may have changed by then.
    final colors = AppColors.of(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    for (final status in HouseDotStatus.values) {
      if (!mounted) return;
      await controller.addImage(
        houseDotImage(status),
        await houseDotPng(HouseDotLook.of(status, colors), pixelRatio),
      );
    }
    if (!mounted) return;
    await controller.addImage(
      pickedMarkImage,
      await houseDotPng(HouseDotLook.pickedMark(colors), pixelRatio),
    );
    _shownLines = widget.layers.lines;
    _shownDots = widget.layers.dots;
    _shownRoad = widget.selectedRoad;
    _shownPoint = widget.selectedPoint;
    _shownPicks = widget.pickedRoads;
    _shownZone = widget.zone;
    await controller.addGeoJsonSource(
      MapIds.streetsSource,
      streetLinesGeoJson(_shownLines!),
    );
    await controller.addGeoJsonSource(
      MapIds.housesSource,
      houseDotsGeoJson(_shownDots!),
    );
    await controller.addGeoJsonSource(
      MapIds.selectedSource,
      selectedRoadGeoJson(_shownRoad!),
    );
    await controller.addGeoJsonSource(
      MapIds.selectedPointSource,
      selectedPointGeoJson(_shownPoint),
    );
    await controller.addGeoJsonSource(
      MapIds.pickedSource,
      pickedRoadsGeoJson(_shownPicks!),
    );
    await controller.addGeoJsonSource(
      MapIds.pickedMarksSource,
      pickedMarksGeoJson(_shownPicks!),
    );
    await controller.addGeoJsonSource(
      MapIds.zoneSource,
      zoneGeoJson(_shownZone),
    );
    final below = lineLayersBelow(await controller.getLayerIds());
    for (final layer in sectorMapLayers(colors)) {
      if (!mounted) return;
      await controller.addLayer(
        layer.source,
        layer.id,
        layer.properties,
        belowLayerId: layer.belowLabels ? below : null,
        enableInteraction: layer.interactive,
        minzoom: layer.minZoom,
        filter: layer.filter,
      );
    }
    if (!mounted) return;
    _styleReady = true;
    await _measureZone();
    // The screen may have sent new data while the layers were added.
    await _sync();
    await _fit(animate: false);
  }

  /// Sends the map whatever changed since it was last sent.
  Future<void> _sync() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    if (!listEquals(_shownLines, widget.layers.lines)) {
      _shownLines = widget.layers.lines;
      await controller.setGeoJsonSource(
        MapIds.streetsSource,
        streetLinesGeoJson(_shownLines!),
      );
    }
    if (!listEquals(_shownDots, widget.layers.dots)) {
      _shownDots = widget.layers.dots;
      await controller.setGeoJsonSource(
        MapIds.housesSource,
        houseDotsGeoJson(_shownDots!),
      );
    }
    if (_shownRoad != widget.selectedRoad) {
      _shownRoad = widget.selectedRoad;
      await controller.setGeoJsonSource(
        MapIds.selectedSource,
        selectedRoadGeoJson(_shownRoad!),
      );
    }
    if (_shownPoint != widget.selectedPoint) {
      _shownPoint = widget.selectedPoint;
      await controller.setGeoJsonSource(
        MapIds.selectedPointSource,
        selectedPointGeoJson(_shownPoint),
      );
    }
    if (!listEquals(_shownPicks, widget.pickedRoads)) {
      _shownPicks = widget.pickedRoads;
      await controller.setGeoJsonSource(
        MapIds.pickedSource,
        pickedRoadsGeoJson(_shownPicks!),
      );
      await controller.setGeoJsonSource(
        MapIds.pickedMarksSource,
        pickedMarksGeoJson(_shownPicks!),
      );
    }
    if (_shownZone != widget.zone) {
      _shownZone = widget.zone;
      await controller.setGeoJsonSource(
        MapIds.zoneSource,
        zoneGeoJson(_shownZone),
      );
      await _measureZone();
    }
  }

  /// How many of MapLibre's screen units make one logical pixel: Android's
  /// map counts physical pixels.
  double get _screenScale => defaultTargetPlatform == TargetPlatform.android
      ? MediaQuery.devicePixelRatioOf(context)
      : 1;

  /// Measures where the zone shown is on screen.
  Future<void> _measureZone() async {
    final controller = _controller;
    final zone = _shownZone;
    if (controller == null || zone == null || !mounted) {
      _zoneOnScreen = null;
      return;
    }
    final scale = _screenScale;
    final corners = await controller.toScreenLocationBatch([
      LatLng(zone.north, zone.west),
      LatLng(zone.south, zone.east),
    ]);
    // Measured for another zone, or none, since the call left.
    if (_shownZone != zone) return;
    _zoneOnScreen = Rect.fromPoints(
      Offset(corners[0].x / scale, corners[0].y / scale),
      Offset(corners[1].x / scale, corners[1].y / scale),
    );
  }

  /// The rectangle [drawn] on screen, in logical pixels, as an area of the
  /// map, handed to [SectorMap.onZoneDrawn].
  Future<void> _zoneDrawn(Rect drawn) async {
    final controller = _controller;
    final onZoneDrawn = widget.onZoneDrawn;
    if (controller == null || onZoneDrawn == null) return;
    final scale = _screenScale;
    final northWest = await controller.toLatLng(
      Point(drawn.left * scale, drawn.top * scale),
    );
    final southEast = await controller.toLatLng(
      Point(drawn.right * scale, drawn.bottom * scale),
    );
    final area = GeoBounds.of(
      south: southEast.latitude,
      west: northWest.longitude,
      north: northWest.latitude,
      east: southEast.longitude,
    );
    if (area == null || !mounted) return;
    onZoneDrawn(area);
  }

  /// Shows the whole [SectorMap.area], clear of [SectorMap.padding].
  Future<void> _fit({required bool animate}) async {
    final controller = _controller;
    final area = widget.area;
    if (controller == null || !_styleReady || area == null) return;
    final padding = widget.padding;
    final update = CameraUpdate.newLatLngBounds(
      latLngBoundsOf(area),
      left: padding.left + AppSizes.gutter,
      top: padding.top + AppSizes.gutter,
      right: padding.right + AppSizes.gutter,
      bottom: padding.bottom + AppSizes.gutter,
    );
    await (animate
        ? controller.animateCamera(update)
        : controller.moveCamera(update));
  }

  /// Moves the map, if needed, so [SectorMap.keepInView] is clear of
  /// [SectorMap.padding] (`cameraReveal`). Waits for a fit on its way: the
  /// screen positions are read once the camera stops.
  Future<void> _reveal() async {
    final controller = _controller;
    final target = widget.keepInView;
    if (controller == null || !_styleReady || _fitting || target == null) {
      return;
    }
    final size = context.size;
    if (size == null) return;
    final scale = _screenScale;
    final corners = await controller.toScreenLocationBatch([
      LatLng(target.north, target.west),
      LatLng(target.south, target.east),
    ]);
    // Something else to show since the call left, or the screen closed.
    if (!mounted || widget.keepInView != target) return;
    final padding = widget.padding;
    const margin = AppSizes.keptInViewMargin;
    final free = Rect.fromLTRB(
      padding.left + margin,
      padding.top + margin,
      size.width - padding.right - margin,
      size.height - padding.bottom - margin,
    );
    final onScreen = Rect.fromPoints(
      Offset(corners[0].x / scale, corners[0].y / scale),
      Offset(corners[1].x / scale, corners[1].y / scale),
    );
    switch (cameraReveal(onScreen, free)) {
      case StayPut():
        return;
      case PanBy(:final offset):
        // For everything to slide by `offset`, the point now that far
        // the other way from the centre becomes the centre.
        final centre = size.center(Offset.zero) - offset;
        final newCentre = await controller.toLatLng(
          Point(centre.dx * scale, centre.dy * scale),
        );
        if (!mounted) return;
        await controller.animateCamera(CameraUpdate.newLatLng(newCentre));
      case FitTarget():
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            latLngBoundsOf(target),
            left: padding.left + margin,
            top: padding.top + margin,
            right: padding.right + margin,
            bottom: padding.bottom + margin,
          ),
        );
    }
  }

  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (tappedStreet(layerId, id) case final street?) {
      widget.onStreetTapped?.call(street);
    } else if (tappedPick(layerId, id) case final pick?) {
      widget.onPickTapped?.call(pick);
    }
  }

  void _onMapClick(Point<double> point, LatLng coordinates) {
    if (geoPointOf(coordinates) case final position?) {
      widget.onMapTapped?.call(position);
    }
  }

  void _onCameraIdle() {
    final fitted = _fitting;
    _fitting = false;
    // A target kept in view while the area was fitted: shown once the
    // camera stopped.
    if (fitted && _revealing) unawaited(_reveal());
    unawaited(_measureZone());
    if (_controller?.cameraPosition case final camera?) {
      widget.onZoomChanged?.call(camera.zoom);
    }
  }

  void _onLocated(GeoPoint position) {
    // The user sent the map elsewhere: a panel growing no longer brings it
    // back.
    _revealing = false;
    setState(() => _showPhone = true);
    final controller = _controller;
    if (controller == null) return;
    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(latLngOf(position), locateZoom),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding;
    return Stack(
      children: [
        Semantics(
          container: true,
          label: AppLocalizations.of(context).mapLabel,
          // A finger on the map: the user moves it, or taps or draws what
          // will be kept in view next. Until then, the map stays where it
          // is put.
          child: Listener(
            onPointerDown: (_) => _revealing = false,
            child: ZoneDrawing(
              enabled: widget.zoneMode,
              zoneOnScreen: () => _zoneOnScreen,
              onDrawn: (drawn) => unawaited(_zoneDrawn(drawn)),
              // Rebuilt with the map free to move under two fingers: the
              // plugin sends the new option to the native map, which reads it
              // on the gesture's next move.
              onTwoFingersChanged: (two) => setState(() => _twoFingers = two),
              child: MapLibreMap(
                styleString: openFreeMapStyle,
                initialCameraPosition: initialCamera(widget.area),
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: _onStyleLoaded,
                onMapClick: _onMapClick,
                // Keeps `controller.cameraPosition` up to date, read when the
                // camera stops.
                trackCameraPosition: true,
                onCameraIdle: _onCameraIdle,
                // A map that turns or tilts under a gloved finger in the street
                // is harder to read than it is useful: north stays up.
                // Our streets and dots are sources and layers of our own: none
                // of MapLibre's annotation layers is needed. Without them, the
                // style loading also adds nothing that could fail once the map
                // has left the screen.
                annotationOrder: const [],
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                compassEnabled: false,
                myLocationEnabled: _showPhone,
                // The ⓘ button shows « © OpenStreetMap, OpenFreeMap » from the
                // tiles: required by their terms (docs/spikes/map.md), kept
                // clear of the panels over the map.
                attributionButtonMargins: Point(
                  padding.right + AppSizes.glyphGap,
                  padding.bottom + AppSizes.glyphGap,
                ),
                // « Zone » on: one finger draws the zone, the map stays put;
                // two fingers move it.
                scrollGesturesEnabled: !widget.zoneMode || _twoFingers,
              ),
            ),
          ),
        ),
        Positioned(
          top: padding.top + AppSizes.mapControlsMargin,
          right: padding.right + AppSizes.mapControlsMargin,
          child: LocateMeButton(
            phone: widget.phoneLocation,
            onLocated: _onLocated,
          ),
        ),
      ],
    );
  }
}
