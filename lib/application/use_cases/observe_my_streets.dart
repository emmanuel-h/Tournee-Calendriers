import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/use_cases/observe_streets.dart';
import 'package:tournee_calendriers/domain/street/my_streets.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// The streets of Accueil (PLAN §5.3): « Mes rues », those the member using
/// the phone covers, and the others of the tournée, each list in French
/// order, now and after each change. Works offline.
///
/// Streets in the Corbeille are left out.
final class ObserveMyStreets {
  const ObserveMyStreets(this._streets, this._identity);

  final StreetRepository _streets;
  final IdentityProvider _identity;

  Stream<MyStreets> call() => ObserveStreets(
    _streets,
  )().map((streets) => MyStreets.of(streets, _identity.currentMember));
}
