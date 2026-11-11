import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';

/// Why a [SidePart] or a [StreetPart] cannot be made.
enum StreetPartFailure {
  /// A bound is below 0 or above [HouseNumber.maxNumber].
  boundOutOfRange,

  /// « Du n° 21 au n° 7 »: the first bound is above the last.
  reversedRange,

  /// A bound of the odd side is even, or one of the even side odd: no
  /// house of that side has that number.
  boundOnOtherSide,
}

/// What a secteur holds of one side of a street (PLAN §5.15): every number
/// ([SidePart.all]), none ([SidePart.none]), or a [NumberRange].
///
/// `sealed`: these three are the only kinds, so a `switch` over a
/// `SidePart` (the stored form, the French words) handles each one.
sealed class SidePart {
  const SidePart();

  /// Every number of the side.
  static const all = AllNumbers._();

  /// No number of the side.
  static const none = NoNumbers._();

  /// The numbers « du n° [from] au n° [to] », both included, on their
  /// integer part: `3bis` is in a range that holds `3`.
  ///
  /// Refused with [StreetPartFailure.boundOutOfRange] when a bound is not
  /// a house number (`0..99999`), and [StreetPartFailure.reversedRange]
  /// when [from] is above [to]. Which side the bounds belong to is checked
  /// by [StreetPart.create], which knows the side.
  static Result<SidePart, StreetPartFailure> range(int from, int to) {
    if (from < 0 ||
        to < 0 ||
        from > HouseNumber.maxNumber ||
        to > HouseNumber.maxNumber) {
      return const Err(StreetPartFailure.boundOutOfRange);
    }
    if (from > to) return const Err(StreetPartFailure.reversedRange);
    return Ok(NumberRange._(from, to));
  }

  /// Whether a house whose integer part is [number] is in this part.
  bool holdsNumber(int number);

  /// Whether every number this part holds, [other] holds too.
  bool isWithin(SidePart other);
}

/// Every number of the side: [SidePart.all].
final class AllNumbers extends SidePart {
  const AllNumbers._();

  @override
  bool holdsNumber(int number) => true;

  @override
  bool isWithin(SidePart other) => other is AllNumbers;

  @override
  String toString() => 'all';
}

/// No number of the side: [SidePart.none].
final class NoNumbers extends SidePart {
  const NoNumbers._();

  @override
  bool holdsNumber(int number) => false;

  @override
  bool isWithin(SidePart other) => true;

  @override
  String toString() => 'none';
}

/// The numbers of the side « du n° [from] au n° [to] », both included.
final class NumberRange extends SidePart {
  const NumberRange._(this.from, this.to);

  /// The first number held, its integer part.
  final int from;

  /// The last number held, its integer part (`21` also holds `21bis`).
  final int to;

  @override
  bool holdsNumber(int number) => from <= number && number <= to;

  @override
  bool isWithin(SidePart other) => switch (other) {
    AllNumbers() => true,
    NoNumbers() => false,
    NumberRange() => other.from <= from && to <= other.to,
  };

  @override
  bool operator ==(Object other) =>
      other is NumberRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '$from–$to';
}

/// What a secteur holds of a street, side by side (PLAN §5.15): the odd
/// side and the even side, each [SidePart.all], [SidePart.none] or a
/// range. A street may be cut in the middle, by side, or both, and shared
/// between secteurs.
///
/// The part is stored on the street. Only the numbers it holds are stored
/// (« + numéros » may add one outside it, which is kept), so every
/// progress figure counts only the numbers held with no change.
/// [StreetPart.whole], both sides whole, is « Toute la rue » and the
/// default.
final class StreetPart {
  const StreetPart._(this.odd, this.even);

  /// « Toute la rue »: every number of both sides.
  static const whole = StreetPart._(SidePart.all, SidePart.all);

  /// The part holding [odd] of the odd side and [even] of the even side.
  ///
  /// Refused with [StreetPartFailure.boundOnOtherSide] when a range bound
  /// is not on its side (an even bound on the odd side): « impairs 6–22 »
  /// would mean « impairs 7–21 » while saying otherwise.
  static Result<StreetPart, StreetPartFailure> create({
    required SidePart odd,
    required SidePart even,
  }) {
    if (!_boundsOn(odd, isOdd: true) || !_boundsOn(even, isOdd: false)) {
      return const Err(StreetPartFailure.boundOnOtherSide);
    }
    return Ok(StreetPart._(odd, even));
  }

  /// Whether the bounds of [side], when it is a range, are odd ([isOdd])
  /// or even.
  static bool _boundsOn(SidePart side, {required bool isOdd}) => switch (side) {
    NumberRange(:final from, :final to) =>
      from.isOdd == isOdd && to.isOdd == isOdd,
    AllNumbers() || NoNumbers() => true,
  };

  /// What is held of the odd side.
  final SidePart odd;

  /// What is held of the even side (0 included).
  final SidePart even;

  /// Whether this is « Toute la rue ».
  bool get isWhole => odd is AllNumbers && even is AllNumbers;

  /// Whether nothing at all is held (« Rien »).
  bool get isNothing => odd is NoNumbers && even is NoNumbers;

  /// Whether the house [number] is in this part: by its side, then by its
  /// integer part (`3bis` goes with `3`).
  bool holds(HouseNumber number) =>
      (number.isOdd ? odd : even).holdsNumber(number.number);

  /// Whether every number this part holds, [other] holds too: going from
  /// [other] to this part adds no number, so it needs no new read of the
  /// numbers.
  bool isWithin(StreetPart other) =>
      odd.isWithin(other.odd) && even.isWithin(other.even);

  @override
  bool operator ==(Object other) =>
      other is StreetPart && other.odd == odd && other.even == even;

  @override
  int get hashCode => Object.hash(odd, even);

  @override
  String toString() => 'StreetPart(odd: $odd, even: $even)';
}
