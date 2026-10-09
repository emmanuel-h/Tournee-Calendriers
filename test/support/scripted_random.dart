import 'dart:math';

/// A [Random] that returns the integers it was given, in order, so a test
/// knows exactly which join code is drawn.
///
/// `Random` from `dart:math` is an interface: the app passes
/// `Random.secure()`, tests pass this. It also records each `max` asked for,
/// so a test can check the draw covers the whole alphabet.
final class ScriptedRandom implements Random {
  ScriptedRandom(Iterable<int> values) : _values = [...values];

  final List<int> _values;
  var _next = 0;

  /// The `max` of each [nextInt] call, in order.
  final List<int> maxima = [];

  @override
  int nextInt(int max) {
    maxima.add(max);
    final value = _values[_next++];
    if (value < 0 || value >= max) {
      throw StateError('scripted value $value is outside 0..${max - 1}');
    }
    return value;
  }

  @override
  bool nextBool() => throw UnimplementedError('not drawn by the domain');

  @override
  double nextDouble() => throw UnimplementedError('not drawn by the domain');
}
