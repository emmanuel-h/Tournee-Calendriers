import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// The steps every street use case shares (PLAN §10.1): load the street
/// [id] from [streets], run [command] on it, save the change it made, and
/// return that change, which the screen keeps for « Annuler ».
///
/// [command] is a function the use case passes in (`(street) =>
/// street.markHouse(…)`), so the loading and saving are written once.
///
/// Two quick taps must not lose one another: the repository answers `find`
/// from memory and takes the new street into memory as soon as `save` is
/// called, before writing it out (the « memory first » promise of
/// [StreetRepository]). No tap can be handled between the two
/// (Dart runs one event at a time, and these steps wait for no outside
/// event), so a second tap reads the street the first one made.
Future<Result<C, CommandFailure<F>>> runOnStreet<C extends StreetChange, F>(
  StreetRepository streets,
  StreetId id,
  Result<(Street, C), F> Function(Street street) command,
) async {
  final street = await streets.find(id);
  if (street == null) return Err(StreetNotFound<F>());
  switch (command(street)) {
    case Err(:final failure):
      return Err(CommandRefused(failure));
    case Ok(value: (final changed, final change)):
      await streets.save(changed, change);
      return Ok(change);
  }
}
