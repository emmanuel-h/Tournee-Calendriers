// A hand-written StreetShapes: answers what the test gives and records each
// call, so a use-case test needs no Overpass.
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

final class FakeStreetShapes implements StreetShapes {
  FakeStreetShapes([this.answer = const Ok(StreetShape.none)]);

  /// The answer to every call.
  Result<StreetShape, StreetShapesFailure> answer;

  /// Run during each call, before it answers: a test plays what happens
  /// meanwhile (a teammate adding the same street).
  Future<void> Function()? whileAsked;

  /// Every call, in order: the street's name and the commune's INSEE code.
  final asked = <(String, String)>[];

  @override
  Future<Result<StreetShape, StreetShapesFailure>> shapeOf({
    required StreetName name,
    required InseeCode commune,
  }) async {
    asked.add((name.text, commune.value));
    await whileAsked?.call();
    return answer;
  }
}
