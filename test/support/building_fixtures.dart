// Buildings shared by the building and street tests.
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';

import 'results.dart';

/// The plan the test knows is valid; by default the Building mockup's
/// staircase: RdC to 5e, four doors a floor, labelled `51`.
BuildingPlan plan({
  int staircases = 1,
  int? topFloor = 5,
  int doors = 4,
  DoorLabelStyle style = DoorLabelStyle.floorAndNumber,
}) => valueOf(
  BuildingPlan.create(
    staircaseCount: staircases,
    topFloor: topFloor,
    doorsPerFloor: doors,
    style: style,
  ),
);

/// A new building laid out by [plan].
Building building({
  int staircases = 1,
  int? topFloor = 5,
  int doors = 4,
  DoorLabelStyle style = DoorLabelStyle.floorAndNumber,
}) => Building.laidOut(
  plan(staircases: staircases, topFloor: topFloor, doors: doors, style: style),
);
