// Binds the street storage the way the composition root does
// (bootstrap/bindings.dart): the phone's own while no tournée is open, the
// open tournée's otherwise. Presentation tests use it to switch tournée
// under a screen and check that it follows.
// `Override` (the type of a container's overrides) lives in misc.dart.
import 'package:flutter_riverpod/misc.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';

/// [phone] while no tournée is open, the street storage of the open one in
/// [sectors] otherwise.
Override streetsOfTheOpenSector({
  required StreetRepository phone,
  required Map<SectorId, StreetRepository> sectors,
}) => streetRepositoryProvider.overrideWith((ref) {
  final sector = ref.watch(currentSectorProvider);
  return sector == null ? phone : sectors[sector.id]!;
});
