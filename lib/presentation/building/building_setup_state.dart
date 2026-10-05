import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';

// The view state of the « Décrire l'immeuble » sheet (PLAN §5.7, mockup
// BuildingSetup), opened by « Transformer en immeuble… » and « Modifier les
// étages ».

/// One floor of the preview: « 1er 11–14 ». [first] and [last] are the
/// same when the floor has one door.
typedef FloorRange = ({int? level, String first, String last});

/// One part of the preview line: the [staircases] it covers (« Esc. A et
/// B »), then some of their floors.
final class PreviewPart {
  PreviewPart._({
    required List<StaircaseName> staircases,
    required List<FloorRange> floors,
    required this.skipsFloors,
  }) : staircases = List.unmodifiable(staircases),
       floors = List.unmodifiable(floors);

  /// The staircases, A first.
  final List<StaircaseName> staircases;

  /// The floors shown, RdC first.
  final List<FloorRange> floors;

  /// Floors are left out between the last two of [floors] (« … »).
  final bool skipsFloors;
}

/// « Aperçu · 48 logements » and « Esc. A et B : RdC 01–04, 1er 11–14 … 5e
/// 51–54 », or « Esc. A : RdC 01–04 … 5e 51–54 · Esc. B : RdC 01–02 … 2e
/// 21–22 » when the staircases differ: what a plan lays out, in short.
final class BuildingPreview {
  BuildingPreview._({
    required this.dwellings,
    required this.namesStaircases,
    required List<PreviewPart> parts,
  }) : parts = List.unmodifiable(parts);

  /// The preview of [plan].
  ///
  /// Staircases alike make one part: their floors are those of the first.
  /// Up to three floors are all given; from four on, the RdC, the 1er and
  /// the top floor, with a gap. Staircases that differ make one part each,
  /// shorter since there are several: the RdC and the top floor, with a
  /// gap when floors lie between.
  factory BuildingPreview.of(BuildingPlan plan) {
    final staircases = plan.generate();
    return BuildingPreview._(
      dwellings: plan.dwellingCount,
      namesStaircases: staircases.length > 1,
      parts: plan.isUniform
          ? [
              _part(
                [for (final staircase in staircases) staircase.name],
                staircases.first,
                shown: (floors) => floors.length > 3
                    ? [floors[0], floors[1], floors.last]
                    : floors,
              ),
            ]
          : [
              for (final staircase in staircases)
                _part(
                  [staircase.name],
                  staircase,
                  shown: (floors) =>
                      floors.length > 2 ? [floors.first, floors.last] : floors,
                ),
            ],
    );
  }

  /// The part of [names] showing the floors of [staircase] that [shown]
  /// picks; a gap when it leaves some out.
  static PreviewPart _part(
    List<StaircaseName> names,
    Staircase staircase, {
    required List<FloorRange> Function(List<FloorRange> floors) shown,
  }) {
    // Floors come top first; the preview reads them from the bottom up.
    final floors = [
      for (final floor in staircase.floors.reversed)
        (
          level: floor.level,
          first: floor.dwellings.first.label.text,
          last: floor.dwellings.last.label.text,
        ),
    ];
    final picked = shown(floors);
    return PreviewPart._(
      staircases: names,
      floors: picked,
      skipsFloors: picked.length < floors.length,
    );
  }

  /// How many dwellings the plan lays out.
  final int dwellings;

  /// Whether the building has several staircases, so each part says which
  /// it covers (« Esc. A et B : »); a single staircase is not named.
  final bool namesStaircases;

  /// The parts of the line, staircase A first.
  final List<PreviewPart> parts;
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
    required this.sameForEach,
    required this.refusal,
  }) : preview = BuildingPreview.of(plan);

  final String streetName;
  final HouseNumber number;

  /// The steppers and the label style show its values.
  final BuildingPlan plan;

  /// « Même chose pour chaque escalier » is ticked: one « Étages » and one
  /// « Portes par étage » stepper set every staircase alike. Untick it and
  /// each staircase has its own.
  final bool sameForEach;

  /// The « Même chose pour chaque escalier » box shows only when there is
  /// more than one staircase to make alike.
  bool get offersSameForEach => plan.staircaseCount > 1;

  /// Each staircase shows its own steppers (« ESC. A », « ESC. B »…).
  bool get stepsEachStaircase => offersSameForEach && !sameForEach;

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
