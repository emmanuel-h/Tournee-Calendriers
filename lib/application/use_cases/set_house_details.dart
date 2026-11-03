import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/application/use_cases/round_visits.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/round/round_visit.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// One choice of a house's status picker (PLAN §5.6): the status, the time
/// of the « repasser », or « De nouveau personne ». On a building it sets the
/// building's own « repasser » (« Repasser » under the grid); its status is
/// refused, its doors carry the statuses. A house made ✓ or ⊘, or taken
/// back, is told to the tournée on (PLAN §5.13). Needs no network.
final class SetHouseDetails {
  const SetHouseDetails(
    this._streets,
    this._clock,
    this._identity,
    this._rounds,
  );

  final StreetRepository _streets;
  final Clock _clock;
  final IdentityProvider _identity;
  final RoundVisits _rounds;

  Future<Result<HouseChange, CommandFailure<HouseChangeFailure>>> call(
    StreetId streetId,
    HouseNumber number,
    Mark mark,
  ) async {
    final by = _identity.currentMember;
    final at = _clock.now();
    final result = await runOnStreet(
      _streets,
      streetId,
      (street) => switch (mark) {
        StatusMark(:final status) => street.markHouse(
          number,
          status,
          by: by,
          at: at,
        ),
        NobodyHomeAgainMark() => street.markNobodyHomeAgain(
          number,
          by: by,
          at: at,
        ),
        ComeBackMark(:final comeBack) => street.setComeBack(
          number,
          comeBack,
          by: by,
          at: at,
        ),
      },
    );
    if (result case Ok(value: final change)) {
      await _rounds.note(RoundVisit.of(change));
    }
    return result;
  }
}
