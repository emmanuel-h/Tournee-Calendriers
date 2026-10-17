import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// « Me l'attribuer » and « La faire aussi » (PLAN §5.4): the member on the
/// phone takes a street of the tournée, next to those who cover it already.
/// The street joins their « Mes rues ». Needs no network.
///
/// Returns the change, which `UndoLastChange` can undo.
final class TakeStreet {
  const TakeStreet(this._streets, this._identity);

  final StreetRepository _streets;
  final IdentityProvider _identity;

  Future<Result<StreetTaken, CommandFailure<AssignmentFailure>>> call(
    StreetId streetId,
  ) => runOnStreet(
    _streets,
    streetId,
    (street) => street.take(_identity.currentMember),
  );
}

/// « Ne plus la faire » (PLAN §5.4, §5.5): the member on the phone stops
/// covering a street; it leaves their « Mes rues » and stays in the
/// tournée, with its marks, for whoever else covers it. Needs no network.
///
/// Returns the change, which `UndoLastChange` can undo.
final class ReleaseStreet {
  const ReleaseStreet(this._streets, this._identity);

  final StreetRepository _streets;
  final IdentityProvider _identity;

  Future<Result<StreetReleased, CommandFailure<AssignmentFailure>>> call(
    StreetId streetId,
  ) => runOnStreet(
    _streets,
    streetId,
    (street) => street.release(_identity.currentMember),
  );
}
