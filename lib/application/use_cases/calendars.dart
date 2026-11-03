import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// Where calendars are counted (#114): the house [number] of the street
/// [street], or its door [door] when it is a building. A record: two
/// places with the same fields are equal.
typedef CalendarPlace = ({
  StreetId street,
  HouseNumber number,
  DwellingKey? door,
});

/// « − » in the status picker of a house or door done (« Un calendrier de
/// moins », PLAN §5.6): it took one calendar less. Never changes a don:
/// dons know no house (PLAN §5.13). Works with or without a tournée on, so
/// a mistake is fixed afterwards too. Needs no network.
final class RemoveCalendar {
  const RemoveCalendar(this._streets, this._clock, this._identity);

  final StreetRepository _streets;
  final Clock _clock;
  final IdentityProvider _identity;

  /// Returns the change stored, or why it was refused (the last calendar, a
  /// house no longer done…).
  Future<Result<StreetChange, CommandFailure<CalendarChangeFailure>>> call(
    CalendarPlace place,
  ) {
    final by = _identity.currentMember;
    final at = _clock.now();
    return runOnStreet(
      _streets,
      place.street,
      (street) =>
          street.removeCalendar(place.number, door: place.door, by: by, at: at),
    );
  }
}
