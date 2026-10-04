/// The name of a staircase of a building: one capital letter, `A` to `Z`
/// (« Esc. A », PLAN §5.7).
///
/// Staircases are named by the app when it lays the building out, never
/// typed by a person, so a wrong name is a bug and throws an [ArgumentError]
/// (like an identifier). The single letter also keeps the dwelling key of
/// storage unambiguous: `A5-51` is staircase `A`, 5e, door `51` (PLAN §6.2).
final class StaircaseName {
  /// Throws an [ArgumentError] unless [letter] is one capital letter A–Z.
  StaircaseName(this.letter) {
    if (!_shape.hasMatch(letter)) {
      throw ArgumentError.value(letter, 'letter', 'must be one letter A-Z');
    }
  }

  /// The name of the staircase at [index] in its building: 0 is `A`, 1 is
  /// `B`… Throws an [ArgumentError] outside `0..maxCount - 1`.
  factory StaircaseName.at(int index) {
    if (index < 0 || index >= maxCount) {
      throw RangeError.range(index, 0, maxCount - 1, 'index');
    }
    // 65 is the character code of `A`; the letters follow in order.
    return StaircaseName(String.fromCharCode(65 + index));
  }

  /// The most staircases a building can have: one per letter.
  static const maxCount = 26;

  static final _shape = RegExp(r'^[A-Z]$');

  final String letter;

  @override
  bool operator ==(Object other) =>
      other is StaircaseName && other.letter == letter;

  @override
  int get hashCode => letter.hashCode;

  @override
  String toString() => 'StaircaseName($letter)';
}
