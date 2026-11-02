import 'package:tournee_calendriers/application/use_cases/observe_streets.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/street/streets_by_member.dart';

/// The streets each member covers, for Équipe (PLAN §5.8: « Léa · 3 rues »
/// and their names), now and after each change. Each member's streets are
/// in French order, as on Accueil. Works offline, from the phone's copy.
///
/// Streets in the Corbeille are left out.
final class ObserveStreetsByMember {
  const ObserveStreetsByMember(this._streets);

  final StreetRepository _streets;

  Stream<StreetsByMember> call() =>
      ObserveStreets(_streets)().map(StreetsByMember.of);
}
