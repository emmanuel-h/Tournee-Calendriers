import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/application/use_cases/round_visits.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/round/round_visit.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// A door of the Immeuble grid (PLAN §5.7), from its status picker (PLAN
/// §5.6): its status, the time of its « repasser », or « De nouveau
/// personne ». Only that door is stamped and stored. A door made ✓ or ⊘, or
/// taken back, is told to the tournée on (PLAN §5.13). Needs no network.
final class MarkDwelling {
  const MarkDwelling(this._streets, this._clock, this._identity, this._rounds);

  final StreetRepository _streets;
  final Clock _clock;
  final IdentityProvider _identity;
  final RoundVisits _rounds;

  Future<Result<DwellingChange, CommandFailure<DwellingChangeFailure>>> call(
    StreetId streetId,
    HouseNumber number,
    DwellingKey key,
    Mark mark,
  ) async {
    final by = _identity.currentMember;
    final at = _clock.now();
    final result = await runOnStreet(
      _streets,
      streetId,
      (street) => switch (mark) {
        StatusMark(:final status) => street.markDwelling(
          number,
          key,
          status,
          by: by,
          at: at,
        ),
        NobodyHomeAgainMark() => street.markDwellingNobodyHomeAgain(
          number,
          key,
          by: by,
          at: at,
        ),
        ComeBackMark(:final comeBack) => street.setDwellingComeBack(
          number,
          key,
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
