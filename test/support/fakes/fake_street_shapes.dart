// A hand-written StreetShapes: answers what the test gives and records each
// call, so a use-case test needs no map tiles.
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

final class FakeStreetShapes implements StreetShapes {
  FakeStreetShapes([this.answer = const Ok(StreetShape.none)]);

  /// The answer to every call.
  Result<StreetShape, StreetShapesFailure> answer;

  /// Run during each call, before it answers: a test plays what happens
  /// meanwhile (a teammate filling the same street).
  Future<void> Function()? whileAsked;

  /// Every call, in order: the street's name and the area looked in.
  final asked = <(String, GeoBounds)>[];

  /// The names asked, in order.
  List<String> get askedNames => [for (final (name, _) in asked) name];

  @override
  Future<Result<StreetShape, StreetShapesFailure>> shapeOf({
    required StreetName name,
    required GeoBounds area,
  }) async {
    asked.add((name.text, area));
    await whileAsked?.call();
    return answer;
  }
}
