import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// A door of the Immeuble grid (PLAN §5.7): a tap gives it a status, a long
/// press opens its sheet (status, hint of its « repasser », note). Only that door is stamped and
/// stored. Needs no network.
final class MarkDwelling {
  const MarkDwelling(this._streets, this._clock, this._identity);

  final StreetRepository _streets;
  final Clock _clock;
  final IdentityProvider _identity;

  Future<Result<DwellingChange, CommandFailure<DwellingChangeFailure>>> call(
    StreetId streetId,
    HouseNumber number,
    DwellingKey key,
    Mark mark,
  ) {
    final by = _identity.currentMember;
    final at = _clock.now();
    return runOnStreet(
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
        ComeBackMark(:final comeBack) => street.setDwellingComeBack(
          number,
          key,
          comeBack,
          by: by,
          at: at,
        ),
        NoteMark(:final note) => street.setDwellingNote(
          number,
          key,
          note,
          by: by,
          at: at,
        ),
      },
    );
  }
}
