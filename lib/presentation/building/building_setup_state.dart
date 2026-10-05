import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';

// The view state of the « Décrire l'immeuble » sheet (PLAN §5.7, mockup
// BuildingSetup), opened by « Transformer en immeuble… » and « Modifier les
// étages ».

/// One floor of the preview: « 1er 11–14 ». [first] and [last] are the
/// same when the floor has one door.
typedef FloorRange = ({int? level, String first, String last});

/// « Aperçu · 48 logements » and « Esc. A et B : RdC 01–04, 1er 11–14 … 5e
/// 51–54 »: what a plan lays out, in short.
final class BuildingPreview {
  BuildingPreview._({
    required this.dwellings,
    required List<StaircaseName> staircases,
    required List<FloorRange> floors,
    required this.skipsFloors,
  }) : staircases = List.unmodifiable(staircases),
       floors = List.unmodifiable(floors);

  /// The preview of [plan]. Every staircase has the same floors, so those
  /// of the first stand for all. Up to three floors are all given; from
  /// four on, the RdC, the 1er and the top floor, with [skipsFloors].
  factory BuildingPreview.of(BuildingPlan plan) {
    final staircases = plan.generate();
    // Floors come top first; the preview reads them from the bottom up.
    final floors = [
      for (final floor in staircases.first.floors.reversed)
        (
          level: floor.level,
          first: floor.dwellings.first.label.text,
          last: floor.dwellings.last.label.text,
        ),
    ];
    final skips = floors.length > 3;
    return BuildingPreview._(
      dwellings: plan.dwellingCount,
      staircases: [for (final staircase in staircases) staircase.name],
      floors: skips ? [floors[0], floors[1], floors.last] : floors,
      skipsFloors: skips,
    );
  }

  /// How many dwellings the plan lays out.
  final int dwellings;

  /// The staircases, A first.
  final List<StaircaseName> staircases;

  /// The floors shown, RdC first.
  final List<FloorRange> floors;

  /// Floors are left out between the last two of [floors] (« … »).
  final bool skipsFloors;
}

/// Everything the sheet shows. `sealed`: the sheet handles each case.
sealed class BuildingSetupState {
  const BuildingSetupState();
}

/// The street is being read from the phone (a moment, at most).
final class BuildingSetupLoading extends BuildingSetupState {
  const BuildingSetupLoading();
}

/// The number is no longer in a street on the phone.
final class BuildingSetupGone extends BuildingSetupState {
  const BuildingSetupGone();
}

/// The answers so far, always a plan the domain accepts.
final class BuildingSetupShown extends BuildingSetupState {
  BuildingSetupShown({
    required this.streetName,
    required this.number,
    required this.plan,
    required this.refusal,
  }) : preview = BuildingPreview.of(plan);

  final String streetName;
  final HouseNumber number;

  /// The steppers and the label style show its values.
  final BuildingPlan plan;

  /// Why the last stepper or style was refused, until the next one that
  /// is taken; null when none was.
  final BuildingPlanFailure? refusal;

  final BuildingPreview preview;
}

/// What « Valider » did. `sealed`: the sheet handles each case.
sealed class SetupOutcome {
  const SetupOutcome();
}

/// The building is laid out: the sheet closes.
final class SetupLaidOut extends SetupOutcome {
  const SetupLaidOut();
}

/// Nothing was stored yet: the new layout would drop [markedDoors] doors
/// that have marks. The sheet asks, then validates again, confirmed.
final class SetupNeedsConfirmation extends SetupOutcome {
  const SetupNeedsConfirmation(this.markedDoors);

  final int markedDoors;
}

/// The house or its street is no longer on the phone: nothing stored.
final class SetupFailed extends SetupOutcome {
  const SetupFailed();
}
