// A hand-written StreetShapes: answers what the test gives and records each
// call, so a use-case test needs neither IGN BD TOPO nor the map's tiles.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

final class FakeStreetShapes implements StreetShapes {
  FakeStreetShapes([this.answer = const Ok(StreetShape.none)]);

  /// The answer to every [shapeOf], unless [answers] has one for the name.
  Result<StreetShape, StreetShapesFailure> answer;

  /// The answer of [shapeOf] for each street name, before [answer].
  final answers = <String, Result<StreetShape, StreetShapesFailure>>{};

  /// Run during each [shapeOf], before it answers: a test plays what
  /// happens meanwhile (a teammate filling the same street).
  Future<void> Function()? whileAsked;

  /// Every [shapeOf], in order: the street's name and the area looked in.
  final asked = <(String, GeoBounds)>[];

  /// The BAN id of every [shapeOf], in order.
  final idsAsked = <BanStreetId?>[];

  /// The names asked, in order.
  List<String> get askedNames => [for (final (name, _) in asked) name];

  @override
  Future<Result<StreetShape, StreetShapesFailure>> shapeOf({
    required BanStreetId? banId,
    required StreetName name,
    required GeoBounds area,
  }) async {
    asked.add((name.text, area));
    idsAsked.add(banId);
    await whileAsked?.call();
    return answers[name.text] ?? answer;
  }

  /// The answer to every [roadsIn] (IGN BD TOPO's stretches).
  Result<List<BanRoad>, StreetShapesFailure> banRoads = const Ok([]);

  /// Every area [roadsIn] was asked, in order.
  final areasAsked = <GeoBounds>[];

  /// Makes the next [roadsIn] wait until [releaseRoads].
  void holdRoads() => _toHold = Completer();

  /// Lets the [roadsIn] held answer, with [banRoads] as they are then.
  void releaseRoads() => _held!.complete();

  Completer<void>? _toHold;
  Completer<void>? _held;

  @override
  Future<Result<List<BanRoad>, StreetShapesFailure>> roadsIn(
    GeoBounds area,
  ) async {
    areasAsked.add(area);
    final hold = _toHold;
    _toHold = null;
    if (hold != null) _held = hold;
    await hold?.future;
    return banRoads;
  }

  /// The answer to every [namedRoadsIn] (the map's roads by name).
  Result<List<NamedRoad>, StreetShapesFailure> roads = const Ok([]);

  /// Every area [namedRoadsIn] was asked, in order.
  final namedAreasAsked = <GeoBounds>[];

  @override
  Future<Result<List<NamedRoad>, StreetShapesFailure>> namedRoadsIn(
    GeoBounds area,
  ) async {
    namedAreasAsked.add(area);
    return roads;
  }
}
