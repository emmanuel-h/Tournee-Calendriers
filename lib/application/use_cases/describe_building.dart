import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/round_visits.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// What the « Transformer en immeuble… » / « Modifier les étages » sheets
/// ask of a house (PLAN §5.7). `sealed`: a `switch` handles each one.
sealed class BuildingEdit {
  const BuildingEdit();
}

/// Lay the house out as [plan] says: a single house becomes a building, a
/// building is laid out again (doors whose label stays on the same floor of
/// the same staircase keep their marks).
final class LayOutBuilding extends BuildingEdit {
  const LayOutBuilding(this.plan);

  final BuildingPlan plan;
}

/// One more door at the end of the floor [level] (null: « Logements ») of
/// [staircase].
final class AddDoor extends BuildingEdit {
  const AddDoor(this.staircase, this.level);

  final StaircaseName staircase;
  final int? level;
}

/// The door at [key] goes, with its marks.
final class RemoveDoor extends BuildingEdit {
  const RemoveDoor(this.key);

  final DwellingKey key;
}

/// The door at [key] takes the [label] typed (« Gauche »), its marks kept.
final class RenameDoor extends BuildingEdit {
  const RenameDoor(this.key, this.label);

  final DwellingKey key;
  final DwellingLabel label;
}

/// The building becomes a single house again (« or back to a single
/// house », PLAN §5.5).
final class BackToSingleHouse extends BuildingEdit {
  const BackToSingleHouse();
}

/// Describes a building or adjusts it floor by floor, stamped with the
/// member and the time. Needs no network.
///
/// Returns the change ([BuildingLaidOut] or [BuildingRemoved]), whose undo
/// puts the house back as it was, doors and marks included. A ✓ house
/// turned into a building takes its own dons out of the tournée on, as a ✓
/// taken back does, and says which ([Marked.takenOut], PLAN §5.21, #171):
/// they have no house left to belong to. No other edit moves a status, so
/// no other edit tells the tournée anything.
final class DescribeBuilding {
  const DescribeBuilding(
    this._streets,
    this._clock,
    this._identity,
    this._rounds,
  );

  final StreetRepository _streets;
  final Clock _clock;
  final IdentityProvider _identity;
  final RoundVisits _rounds;

  Future<Result<Marked<HouseChange>, CommandFailure<BuildingChangeFailure>>>
  call(StreetId streetId, HouseNumber number, BuildingEdit edit) async {
    final by = _identity.currentMember;
    final at = _clock.now();
    final result = await runOnStreet(
      _streets,
      streetId,
      (street) => switch (edit) {
        LayOutBuilding(:final plan) => street.describeBuilding(
          number,
          plan,
          by: by,
          at: at,
        ),
        AddDoor(:final staircase, :final level) => street.addDoor(
          number,
          staircase,
          level,
          by: by,
          at: at,
        ),
        RemoveDoor(:final key) => street.removeDoor(
          number,
          key,
          by: by,
          at: at,
        ),
        RenameDoor(:final key, :final label) => street.renameDoor(
          number,
          key,
          label,
          by: by,
          at: at,
        ),
        BackToSingleHouse() => street.removeBuilding(number, by: by, at: at),
      },
    );
    switch (result) {
      case Ok(value: final change):
        return Ok(Marked(change, takenOut: await _rounds.noteChange(change)));
      case Err(:final failure):
        return Err(failure);
    }
  }
}
