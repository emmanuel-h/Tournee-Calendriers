import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// One control of the Fiche maison (hold a tile, PLAN §5.7): the status,
/// the « repasser » or the note of a house. On a building it sets the
/// building's own « repasser » and note (« Repasser · Note » under the
/// grid); its status is refused, its doors carry the statuses. Needs no
/// network.
///
/// The text of a note or hint is checked by the sheet first (`Note.create`,
/// `ComeBack.create`), so it can say « trop long » before anything is sent.
final class SetHouseDetails {
  const SetHouseDetails(this._streets, this._clock, this._identity);

  final StreetRepository _streets;
  final Clock _clock;
  final IdentityProvider _identity;

  Future<Result<HouseChange, CommandFailure<HouseChangeFailure>>> call(
    StreetId streetId,
    HouseNumber number,
    Mark mark,
  ) {
    final by = _identity.currentMember;
    final at = _clock.now();
    return runOnStreet(
      _streets,
      streetId,
      (street) => switch (mark) {
        StatusMark(:final status) => street.markHouse(
          number,
          status,
          by: by,
          at: at,
        ),
        ComeBackMark(:final comeBack) => street.setComeBack(
          number,
          comeBack,
          by: by,
          at: at,
        ),
        NoteMark(:final note) => street.setNote(number, note, by: by, at: at),
      },
    );
  }
}
