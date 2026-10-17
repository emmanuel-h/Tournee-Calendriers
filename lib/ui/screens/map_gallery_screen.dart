import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/map/tournee_map.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// Debug-only screen showing the map widget on sample streets of
/// Villefranche-sur-Saône, one per progress level and a house per status,
/// to check it on the emulator and a phone before Accueil (T3.5) and
/// « Ajouter des rues » (T3.6) use it.
final class MapGalleryScreen extends StatefulWidget {
  const MapGalleryScreen({super.key});

  @override
  State<MapGalleryScreen> createState() => _MapGalleryScreenState();
}

final class _MapGalleryScreenState extends State<MapGalleryScreen> {
  final _streets = _sampleStreets();
  var _roadSelected = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.galleryMap)),
      body: Column(
        children: [
          Expanded(
            child: TourneeMap(
              layers: MapLayers.of(_streets),
              area: tourneeArea(_streets),
              selectedRoad: _roadSelected ? _selectedRoad : StreetShape.none,
              onStreetTapped: (street) => showMessageSnackBar(
                messenger,
                message: l10n.galleryMapStreetTapped(street.value),
              ),
              onMapTapped: (point) => showMessageSnackBar(
                messenger,
                message: l10n.galleryMapTapped(
                  point.latitude.toStringAsFixed(5),
                  point.longitude.toStringAsFixed(5),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.gutter),
            child: SecondaryButton(
              label: l10n.galleryMapSelectRoad,
              compact: true,
              onPressed: () => setState(() => _roadSelected = !_roadSelected),
            ),
          ),
        ],
      ),
    );
  }
}

/// A road west of the sample streets, as « Ajouter des rues » highlights
/// the road under the finger.
final _selectedRoad = StreetShape([
  [_at(45.98700, 4.71500), _at(45.98850, 4.71560), _at(45.99000, 4.71600)],
]);

List<Street> _sampleStreets() {
  final commune = _ok(
    Commune.create(inseeCode: '69264', name: 'Villefranche-sur-Saône'),
  );
  final lea = MemberId('lea');
  Street street(
    String id,
    String name,
    List<GeoPoint> line,
    List<House> houses, {
    bool taken = true,
  }) => _ok(
    Street.create(
      id: StreetId(id),
      name: name,
      commune: commune,
      shape: StreetShape([line]),
      assignees: {if (taken) lea},
      houses: houses,
    ),
  );
  House house(String number, VisitStatus status, GeoPoint position) => House(
    number: _ok(HouseNumber.parse(number)),
    status: status,
    position: position,
  );

  return [
    street(
      'rue-nationale',
      'Rue Nationale',
      [_at(45.98915, 4.71862), _at(45.99060, 4.71785), _at(45.99210, 4.71705)],
      [
        house('1', VisitStatus.done, _at(45.98925, 4.71872)),
        house('3', VisitStatus.nobodyHome, _at(45.98965, 4.71850)),
        house('5', VisitStatus.comeBack, _at(45.99005, 4.71829)),
        house('7', VisitStatus.toDo, _at(45.99045, 4.71808)),
        house('2', VisitStatus.done, _at(45.98945, 4.71834)),
        house('4', VisitStatus.toDo, _at(45.98985, 4.71813)),
      ],
    ),
    street(
      'rue-des-lilas',
      'Rue des Lilas',
      [_at(45.98915, 4.71862), _at(45.98880, 4.72050)],
      [
        house('2', VisitStatus.done, _at(45.98908, 4.71930)),
        house('4', VisitStatus.done, _at(45.98898, 4.71990)),
      ],
    ),
    street(
      'allee-des-pins',
      'Allée des Pins',
      [_at(45.99060, 4.71785), _at(45.99090, 4.71980)],
      [house('1', VisitStatus.toDo, _at(45.99085, 4.71880))],
    ),
    street(
      'rue-de-la-paix',
      'Rue de la Paix',
      [_at(45.98800, 4.71700), _at(45.98915, 4.71862)],
      [house('8', VisitStatus.toDo, _at(45.98850, 4.71770))],
      taken: false,
    ),
  ];
}

GeoPoint _at(double latitude, double longitude) =>
    _ok(GeoPoint.create(latitude: latitude, longitude: longitude));

/// The sample is written by hand and valid: a failure is a typo here.
T _ok<T>(Result<T, Object?> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('Invalid sample: $failure'),
};
