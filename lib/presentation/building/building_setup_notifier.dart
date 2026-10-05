import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/building/building_setup_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/street/follows_street.dart';

/// Which house the « Décrire l'immeuble » sheet lays out.
typedef BuildingSetupKey = ({StreetId street, HouseNumber number});

/// The state of the « Décrire l'immeuble » sheet of one house.
final buildingSetupProvider = NotifierProvider.autoDispose
    .family<BuildingSetupNotifier, BuildingSetupState, BuildingSetupKey>(
      BuildingSetupNotifier.new,
    );

/// The answers of « Décrire l'immeuble » (« Transformer en immeuble… » on a
/// house, « Modifier les étages » on a building), checked at each step by
/// the domain (`BuildingPlan.perStaircase`), and laid out by « Valider »
/// (`DescribeBuilding`). Needs no network.
///
/// The answers start from the building as it is, or from a small default
/// for a house, and then belong to the sheet: a change of the street
/// meanwhile does not reset them.
final class BuildingSetupNotifier extends Notifier<BuildingSetupState>
    with FollowsStreet<BuildingSetupState> {
  BuildingSetupNotifier(this.key);

  final BuildingSetupKey key;

  /// What a house becomes by default: one staircase, RdC–2e, two doors a
  /// floor, numbered 51 — a small building, quick to adjust from.
  static final _defaultPlan =
      // `as Ok`: this plan is within every limit, so it is always accepted.
      (_tryPlan(
        const [StaircasePlan(topFloor: 2, doorsPerFloor: 2)],
        DoorLabelStyle.floorAndNumber,
      ) as Ok<BuildingPlan, BuildingPlanFailure>).value;

  /// The answers; null until the street is read.
  BuildingPlan? _plan;
  var _sameForEach = true;
  BuildingPlanFailure? _refusal;

  @override
  BuildingSetupState build() {
    followStreet(key.street);
    return render();
  }

  /// One staircase more, with the floors and doors of the last one.
  void addStaircase() =>
      _step((p) => _withStaircases(p, [...p.staircases, p.staircases.last]));

  /// The last staircase goes.
  void removeStaircase() => _step(
    (p) => _withStaircases(p, p.staircases.sublist(0, p.staircases.length - 1)),
  );

  /// « Même chose pour chaque escalier »: ticked, every staircase takes
  /// the floors and doors of staircase A (refused, and left unticked, when
  /// that makes too many dwellings); unticked, each keeps its own.
  void setSameForEach({required bool same}) {
    if (!same) {
      _sameForEach = false;
      _refusal = null;
      state = render();
      return;
    }
    _step(
      (p) => _withStaircases(p, [
        for (final _ in p.staircases) p.staircases.first,
      ]),
      onTaken: () => _sameForEach = true,
    );
  }

  /// One floor more in [staircase], or in every staircase when null: from
  /// unknown floors (« Inconnus ») to the RdC alone, then up.
  void addFloor({StaircaseName? staircase}) =>
      _stepStaircases(staircase, (s) => s.oneFloorMore());

  /// One floor less in [staircase], or in every staircase when null: from
  /// the RdC alone to unknown floors, and nothing below.
  void removeFloor({StaircaseName? staircase}) =>
      _stepStaircases(staircase, (s) => s.oneFloorLess());

  /// One door more on each floor of [staircase], or of every staircase
  /// when null.
  void addDoor({StaircaseName? staircase}) =>
      _stepStaircases(staircase, (s) => s.oneDoorMore());

  /// One door less on each floor of [staircase], or of every staircase
  /// when null.
  void removeDoor({StaircaseName? staircase}) =>
      _stepStaircases(staircase, (s) => s.oneDoorLess());

  /// The « Numéros des portes » choice.
  void setStyle(DoorLabelStyle style) =>
      _step((p) => _tryPlan(p.staircases, style));

  /// « Valider »: lays the house out as the answers say. When that would
  /// drop doors that have marks, nothing is stored unless [confirmed]: the
  /// sheet asks first.
  Future<SetupOutcome> validate({bool confirmed = false}) async {
    final house = _house;
    final plan = _plan;
    if (house == null || plan == null) return const SetupFailed();
    final dropped = house.building?.markedDoorsDroppedBy(plan) ?? 0;
    if (dropped > 0 && !confirmed) return SetupNeedsConfirmation(dropped);
    final result = await ref.read(describeBuildingProvider)(
      key.street,
      key.number,
      LayOutBuilding(plan),
    );
    return switch (result) {
      Ok() => const SetupLaidOut(),
      Err() => const SetupFailed(),
    };
  }

  /// Steps the staircase named [only] with [change], or every staircase
  /// when [only] is null.
  void _stepStaircases(
    StaircaseName? only,
    StaircasePlan Function(StaircasePlan staircase) change,
  ) => _step(
    (p) => _withStaircases(p, [
      for (final (index, staircase) in p.staircases.indexed)
        only == null || StaircaseName.at(index) == only
            ? change(staircase)
            : staircase,
    ]),
  );

  /// Tries the plan [next] makes of the current one: taken when the domain
  /// accepts it (then [onTaken] runs), otherwise the plan stays and the
  /// refusal shows.
  void _step(
    Result<BuildingPlan, BuildingPlanFailure> Function(BuildingPlan plan)
    next, {
    void Function()? onTaken,
  }) {
    final current = _plan;
    if (current == null) return;
    switch (next(current)) {
      case Ok(:final value):
        _plan = value;
        _refusal = null;
        onTaken?.call();
      case Err(:final failure):
        _refusal = failure;
    }
    state = render();
  }

  House? get _house => street?.houseAt(key.number);

  @override
  BuildingSetupState render() {
    if (!streetRead) return const BuildingSetupLoading();
    final house = _house;
    if (house == null) return const BuildingSetupGone();
    // The answers start from the house as first shown, then belong to the
    // sheet.
    final plan = _plan ?? _start(house.building);
    return BuildingSetupShown(
      streetName: street!.name.text,
      number: house.number,
      plan: plan,
      sameForEach: _sameForEach,
      refusal: _refusal,
    );
  }

  /// [current] with [staircases] instead of its own, its style kept.
  static Result<BuildingPlan, BuildingPlanFailure> _withStaircases(
    BuildingPlan current,
    List<StaircasePlan> staircases,
  ) => _tryPlan(staircases, current.style);

  static Result<BuildingPlan, BuildingPlanFailure> _tryPlan(
    List<StaircasePlan> staircases,
    DoorLabelStyle style,
  ) => BuildingPlan.perStaircase(staircases: staircases, style: style);

  /// Takes the first answers from [building] (the default for a house)
  /// and returns them.
  BuildingPlan _start(Building? building) {
    final plan = switch (building?.closestPlan) {
      Ok(:final value) => value,
      // A house, or a building larger than a plan allows.
      null || Err() => _defaultPlan,
    };
    _sameForEach = plan.isUniform;
    return _plan = plan;
  }
}
