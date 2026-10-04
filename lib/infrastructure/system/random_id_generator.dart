import 'dart:math';

import 'package:tournee_calendriers/application/ports/id_generator.dart';

/// The [IdGenerator] of the app: 20 random letters and digits, like a
/// Firestore document id. 62²⁰ possibilities: two phones never make the
/// same id, so ids made offline need no server to stay unique.
final class RandomIdGenerator implements IdGenerator {
  /// [random] is `Random.secure()` by default (the system's generator, not
  /// guessable); tests pass a seeded `Random` to get known ids.
  RandomIdGenerator([Random? random]) : _random = random ?? Random.secure();

  static const length = 20;
  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  final Random _random;

  @override
  String newId() => String.fromCharCodes([
    for (var i = 0; i < length; i++)
      _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
  ]);
}
