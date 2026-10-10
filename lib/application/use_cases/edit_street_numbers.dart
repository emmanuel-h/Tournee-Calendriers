import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// What the edit mode of a street asks (PLAN §5.5). `sealed`: a `switch`
/// handles each one.
sealed class StreetEdit {
  const StreetEdit();
}

/// « + numéros »: the [numbers] read from the sheet (`parseHouseNumbers`).
/// A number already shown is skipped; one in the Corbeille comes back with
/// its marks.
final class AddNumbers extends StreetEdit {
  AddNumbers(Iterable<HouseNumber> numbers)
    : numbers = List.unmodifiable(numbers);

  final List<HouseNumber> numbers;
}

/// ✕ on a number: the house goes to the Corbeille with its marks (the
/// screen asks first when `House.hasMarks`).
final class RemoveNumber extends StreetEdit {
  const RemoveNumber(this.number);

  final HouseNumber number;
}

/// « Restaurer » a number from the Corbeille.
final class RestoreNumber extends StreetEdit {
  const RestoreNumber(this.number);

  final HouseNumber number;
}

/// The number of a house changes (`3` → `3bis`), its marks kept.
final class RenameNumber extends StreetEdit {
  const RenameNumber(this.number, this.newNumber);

  final HouseNumber number;
  final HouseNumber newNumber;
}

/// The name field: the street is renamed for the whole team.
final class RenameStreet extends StreetEdit {
  const RenameStreet(this.name);

  final StreetName name;
}

/// « Supprimer »: the street goes to the Corbeille for everyone, houses and
/// marks kept (the screen asks first).
final class DeleteStreet extends StreetEdit {
  const DeleteStreet();
}

/// « Restaurer » a street from the Corbeille (PLAN §5.11): it is shown
/// again with its houses and marks.
final class RestoreStreet extends StreetEdit {
  const RestoreStreet();
}

/// The edit mode of a street: numbers added, removed, restored or renamed,
/// the street renamed, deleted or restored (from the Corbeille). Needs no
/// network.
///
/// Returns the change, which the screen offers to undo (`UndoLastChange`)
/// except for added numbers (remove them with ✕).
final class EditStreetNumbers {
  const EditStreetNumbers(this._streets, this._clock, this._identity);

  final StreetRepository _streets;
  final Clock _clock;
  final IdentityProvider _identity;

  Future<Result<StreetChange, CommandFailure<NumberChangeFailure>>> call(
    StreetId streetId,
    StreetEdit edit,
  ) {
    final by = _identity.currentMember;
    final at = _clock.now();
    return runOnStreet(
      _streets,
      streetId,
      (street) => switch (edit) {
        AddNumbers(:final numbers) => street.addNumbers(numbers),
        RemoveNumber(:final number) => street.removeNumber(
          number,
          by: by,
          at: at,
        ),
        RestoreNumber(:final number) => street.restoreNumber(number),
        RenameNumber(:final number, :final newNumber) => street.renameNumber(
          number,
          newNumber,
          by: by,
          at: at,
        ),
        // These three cannot be refused: they return a plain (street,
        // change) record, wrapped in `Ok` to match the others.
        RenameStreet(:final name) => Ok(street.renameStreet(name)),
        DeleteStreet() => Ok(street.delete(by: by, at: at)),
        RestoreStreet() => Ok(street.restore()),
      },
    );
  }
}
