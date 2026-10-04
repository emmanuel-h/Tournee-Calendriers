import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// A tap on a house tile (PLAN §5.6): gives the house its next status,
/// stamped with the member and the time, and stores it on the phone. Needs
/// no network.
///
/// Returns the [HouseMarked] change for the snackbar's « Annuler » (see
/// `UndoLastChange`).
final class MarkHouse {
  const MarkHouse(this._streets, this._clock, this._identity);

  final StreetRepository _streets;
  final Clock _clock;
  final IdentityProvider _identity;

  /// `call` lets the use case be invoked like a function:
  /// `markHouse(streetId, number, status)`.
  Future<Result<HouseMarked, CommandFailure<HouseChangeFailure>>> call(
    StreetId streetId,
    HouseNumber number,
    VisitStatus status,
  ) => runOnStreet(
    _streets,
    streetId,
    (street) => street.markHouse(
      number,
      status,
      by: _identity.currentMember,
      at: _clock.now(),
    ),
  );
}
