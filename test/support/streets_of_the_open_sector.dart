// Binds the street storage the way the composition root does
// (bootstrap/bindings.dart): none while no secteur is open, the open
// secteur's otherwise. Presentation tests use it to switch tournée
// under a screen and check that it follows.
// `Override` (the type of a container's overrides) lives in misc.dart.
import 'package:flutter_riverpod/misc.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';

/// [none] while no secteur is open, the street storage of the open one in
/// [sectors] otherwise.
Override streetsOfTheOpenSector({
  required StreetRepository none,
  required Map<SectorId, StreetRepository> sectors,
}) => streetRepositoryProvider.overrideWith((ref) {
  final sector = ref.watch(currentSectorProvider);
  return sector == null ? none : sectors[sector.id]!;
});
