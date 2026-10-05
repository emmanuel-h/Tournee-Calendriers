import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/building/building_setup_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// The four answers of the sheet: staircases, top floor (null: unknown),
/// doors per floor, label style.
typedef _Answers = (int, int?, int, DoorLabelStyle);

/// Which house the « Décrire l'immeuble » sheet lays out.
typedef BuildingSetupKey = ({StreetId street, HouseNumber number});

/// The state of the « Décrire l'immeuble » sheet of one house.
final buildingSetupProvider = NotifierProvider.autoDispose
    .family<BuildingSetupNotifier, BuildingSetupState, BuildingSetupKey>(
      BuildingSetupNotifier.new,
    );

/// The answers of « Décrire l'immeuble » (« Transformer en immeuble… » on a
/// house, « Modifier les étages » on a building), checked at each step by
/// the domain (`BuildingPlan.create`), and laid out by « Valider »
/// (`DescribeBuilding`). Needs no network.
///
/// The answers start from the building as it is, or from a small default
/// for a house, and then belong to the sheet: a change of the street
/// meanwhile does not reset them.
final class BuildingSetupNotifier extends Notifier<BuildingSetupState> {
  BuildingSetupNotifier(this.key);

  final BuildingSetupKey key;

  /// What a house becomes by default: one staircase, RdC–2e, two doors a
  /// floor, numbered 51 — a small building, quick to adjust from.
  static final _defaultPlan = _planOrNull(
    staircases: 1,
    topFloor: 2,
    doors: 2,
    style: DoorLabelStyle.floorAndNumber,
  )!;

  Street? _street;
  var _read = false;

  /// The answers; null until the street is read.
  BuildingPlan? _plan;
  BuildingPlanFailure? _refusal;

  @override
  BuildingSetupState build() {
    final subscription = ref.watch(observeStreetProvider)(key.street).listen((
      street,
    ) {
      _street = street;
      _read = true;
      _plan ??= switch (_house?.building) {
        null => _defaultPlan,
        final building => _planOf(building),
      };
      state = _view();
    });
    ref.onDispose(subscription.cancel);
    return _view();
  }

  void addStaircase() => _step(
    (p) => (p.staircaseCount + 1, p.topFloor, p.doorsPerFloor, p.style),
  );

  void removeStaircase() => _step(
    (p) => (p.staircaseCount - 1, p.topFloor, p.doorsPerFloor, p.style),
  );

  /// One floor more: from unknown floors (« Inconnus ») to the RdC alone,
  /// then up.
  void addFloor() => _step(
    (p) => (
      p.staircaseCount,
      switch (p.topFloor) {
        null => 0,
        final top => top + 1,
      },
      p.doorsPerFloor,
      p.style,
    ),
  );

  /// One floor less: from the RdC alone to unknown floors, and nothing
  /// below.
  void removeFloor() => _step(
    (p) => (
      p.staircaseCount,
      switch (p.topFloor) {
        0 => null,
        // -1 lets the domain refuse it (`belowGroundFloor`), so the sheet
        // says why.
        null => -1,
        final top => top - 1,
      },
      p.doorsPerFloor,
      p.style,
    ),
  );

  void addDoor() => _step(
    (p) => (p.staircaseCount, p.topFloor, p.doorsPerFloor + 1, p.style),
  );

  void removeDoor() => _step(
    (p) => (p.staircaseCount, p.topFloor, p.doorsPerFloor - 1, p.style),
  );

  /// The « Numéros des portes » choice.
  void setStyle(DoorLabelStyle style) =>
      _step((p) => (p.staircaseCount, p.topFloor, p.doorsPerFloor, style));

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

  /// Tries the answers [change] makes of the current plan (staircases,
  /// top floor, doors per floor, style): taken when the domain accepts
  /// them, otherwise the plan stays and the refusal shows.
  void _step(_Answers Function(BuildingPlan plan) change) {
    final current = _plan;
    if (current == null) return;
    final (staircases, topFloor, doors, style) = change(current);
    switch (BuildingPlan.create(
      staircaseCount: staircases,
      topFloor: topFloor,
      doorsPerFloor: doors,
      style: style,
    )) {
      case Ok(:final value):
        _plan = value;
        _refusal = null;
      case Err(:final failure):
        _refusal = failure;
    }
    state = _view();
  }

  House? get _house {
    final street = _street;
    if (street == null || street.isDeleted) return null;
    for (final house in street.houses) {
      if (house.number == key.number) return house;
    }
    return null;
  }

  BuildingSetupState _view() {
    if (!_read) return const BuildingSetupLoading();
    final house = _house;
    if (house == null) return const BuildingSetupGone();
    return BuildingSetupShown(
      streetName: _street!.name,
      number: house.number,
      plan: _plan!,
      refusal: _refusal,
    );
  }

  /// The plan closest to [building]: its staircases and style, its highest
  /// floor and its largest floor. A building adjusted floor by floor may
  /// be larger than a plan allows; the default plan is used then.
  static BuildingPlan _planOf(Building building) {
    final floors = [
      for (final staircase in building.staircases) ...staircase.floors,
    ];
    final unknown = floors.any((floor) => floor.level == null);
    return _planOrNull(
          staircases: building.staircases.length,
          topFloor: unknown
              ? null
              : floors.map((floor) => floor.level!).reduce(math.max),
          doors: floors.map((floor) => floor.dwellings.length).reduce(math.max),
          style: building.style,
        ) ??
        _defaultPlan;
  }

  static BuildingPlan? _planOrNull({
    required int staircases,
    required int? topFloor,
    required int doors,
    required DoorLabelStyle style,
  }) => switch (BuildingPlan.create(
    staircaseCount: staircases,
    topFloor: topFloor,
    doorsPerFloor: doors,
    style: style,
  )) {
    Ok(:final value) => value,
    Err() => null,
  };
}
