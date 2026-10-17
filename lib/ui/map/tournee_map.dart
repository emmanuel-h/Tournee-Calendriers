import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
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
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// The map of a tournée (PLAN §5.3, §5.4): the OpenFreeMap background, the
/// streets coloured by progress, the house dots from street zoom, the road
/// picked on « Ajouter des rues », and « Me localiser ».
///
/// It only draws what it is given: what to show is decided by the domain
/// ([MapLayers]) and the screen; this widget turns it into MapLibre
/// sources and layers (`map_geojson.dart`, `map_style.dart`, both tested)
/// and hands taps back as domain values. It is thin MapLibre glue, covered
/// by the device checklist (PLAN §11): a map cannot run in a widget test.
final class TourneeMap extends StatefulWidget {
  const TourneeMap({
    super.key,
    required this.layers,
    this.selectedRoad = StreetShape.none,
    this.area,
    this.onStreetTapped,
    this.onMapTapped,
    this.onZoomChanged,
    this.padding = EdgeInsets.zero,
    this.phoneLocation = const GeolocatorPhoneLocation(),
  });

  /// The streets and houses to draw.
  final MapLayers layers;

  /// The road picked on « Ajouter des rues », drawn over the others; none
  /// by default.
  final StreetShape selectedRoad;

  /// The area to show: the map fits it when it opens, and again each time
  /// it changes (another tournée opened, a street found by the search).
  /// Null leaves the camera where the user put it.
  final GeoBounds? area;

  /// A tap on one of the tournée's streets, or on one of its house dots.
  final ValueChanged<StreetId>? onStreetTapped;

  /// A tap anywhere else on the map: where the finger was.
  final ValueChanged<GeoPoint>? onMapTapped;

  /// The map's zoom level, each time the camera stops after a move (a
  /// pinch, « Me localiser », a fit): Accueil switches its legend at street
  /// zoom.
  final ValueChanged<double>? onZoomChanged;

  /// The room other widgets take over the map's edges (a banner on top, a
  /// panel at the bottom): « Me localiser », the attribution and the fitted
  /// area keep clear of it.
  final EdgeInsets padding;

  /// The phone's location, for « Me localiser »; tests give a fake.
  final PhoneLocation phoneLocation;

  @override
  State<TourneeMap> createState() => _TourneeMapState();
}

final class _TourneeMapState extends State<TourneeMap> {
  MapLibreMapController? _controller;

  /// Sources and layers can only be added once the style has loaded; until
  /// then the data waits in the widget.
  var _styleReady = false;

  /// What the map shows now, to send only what changed.
  List<StreetLine>? _shownLines;
  List<HouseDot>? _shownDots;
  StreetShape? _shownRoad;

  /// The phone's dot shows once « Me localiser » found it: MapLibre then
  /// follows the position itself, with the access already granted.
  var _showPhone = false;

  @override
  void didUpdateWidget(TourneeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `unawaited`: the map updates on its own time; nothing here waits for
    // it, and a build must never wait.
    unawaited(_sync());
    if (widget.area != oldWidget.area) unawaited(_fit(animate: true));
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
  /// at once): the map's platform side is then gone, and the call on its
  /// way fails with a [MissingPluginException], which means nothing to a
  /// map no longer shown.
  Future<void> _onStyleLoaded() async {
    try {
      await _addOurLayers();
    } on MissingPluginException {
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
    _shownLines = widget.layers.lines;
    _shownDots = widget.layers.dots;
    _shownRoad = widget.selectedRoad;
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
    final below = lineLayersBelow(await controller.getLayerIds());
    for (final layer in tourneeMapLayers(colors)) {
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
  }

  /// Shows the whole [TourneeMap.area], clear of [TourneeMap.padding].
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

  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (tappedStreet(layerId, id) case final street?) {
      widget.onStreetTapped?.call(street);
    }
  }

  void _onMapClick(Point<double> point, LatLng coordinates) {
    if (geoPointOf(coordinates) case final position?) {
      widget.onMapTapped?.call(position);
    }
  }

  void _onCameraIdle() {
    if (_controller?.cameraPosition case final camera?) {
      widget.onZoomChanged?.call(camera.zoom);
    }
  }

  void _onLocated(GeoPoint position) {
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
