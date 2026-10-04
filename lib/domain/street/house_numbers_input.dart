// Domain service: turns what a person types into a list of house numbers,
// for the « Ajouter des numéros » sheet and the manual street form
// (PLAN §5.5). Pure functions: the preview (« Aperçu · 6 numéros ») and the
// command that adds the numbers read the same result.
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';

/// The most numbers one input may give.
///
/// A typo such as `1-99999` must not create 100 000 houses: a street lives
/// in one stored document (PLAN §6.2), and 500 is more than the longest
/// street side of a tournée. Ranges are counted before they are expanded.
const maxNumbersAtOnce = 500;

/// Which sides of the street a range of the manual form covers
/// (« Les deux | Impairs | Pairs »).
enum Sides {
  both,
  odd,

  /// The even side, 0 included.
  even;

  /// Whether [number] is on these sides.
  bool includes(int number) => switch (this) {
    Sides.both => true,
    Sides.odd => number.isOdd,
    Sides.even => number.isEven,
  };
}

/// One of the two number fields of the manual form (« Du n° », « Au n° »).
enum Bound { from, to }

/// Why a typed input gives no list of numbers. Each case says enough for
/// the screen to point at what is wrong.
///
/// A `sealed class` rather than an `enum`, because most cases carry data
/// (the wrong item); a `switch` over it must still handle every case.
sealed class NumbersFailure {
  const NumbersFailure();
}

/// The item [token] (as typed, trimmed) is not a house number, for
/// [reason].
final class InvalidNumber extends NumbersFailure {
  const InvalidNumber(this.token, this.reason);

  final String token;
  final HouseNumberFailure reason;

  @override
  bool operator ==(Object other) =>
      other is InvalidNumber && other.token == token && other.reason == reason;

  @override
  int get hashCode => Object.hash(token, reason);

  @override
  String toString() => 'InvalidNumber($token, $reason)';
}

/// The item [token] has a dash but is not a range of two plain numbers
/// from 0 to [HouseNumber.maxNumber] (`12bis-14`, `21-`, `1-2-3`).
final class InvalidRange extends NumbersFailure {
  const InvalidRange(this.token);

  final String token;

  @override
  bool operator ==(Object other) =>
      other is InvalidRange && other.token == token;

  @override
  int get hashCode => token.hashCode;

  @override
  String toString() => 'InvalidRange($token)';
}

/// The field [bound] of the manual form holds [text], which is not a plain
/// number from 0 to [HouseNumber.maxNumber].
final class InvalidBound extends NumbersFailure {
  const InvalidBound(this.bound, this.text);

  final Bound bound;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is InvalidBound && other.bound == bound && other.text == text;

  @override
  int get hashCode => Object.hash(bound, text);

  @override
  String toString() => 'InvalidBound($bound, $text)';
}

/// The input gives more than [maxNumbersAtOnce] numbers.
final class TooManyNumbers extends NumbersFailure {
  const TooManyNumbers();

  @override
  bool operator ==(Object other) => other is TooManyNumbers;

  @override
  int get hashCode => maxNumbersAtOnce.hashCode;

  @override
  String toString() => 'TooManyNumbers($maxNumbersAtOnce)';
}

/// Reads the « Numéros » field of the « Ajouter des numéros » sheet and the
/// « Numéros en plus » field of the manual form: items separated by commas
/// (also `;` or line breaks), each one number (`12bis`, read like
/// [HouseNumber.parse]) or a range of plain numbers (`21-25`, both sides).
///
/// Spaces around items and empty items are ignored; a range may be typed
/// backwards (`25-21`) or with an en dash. Returns the numbers sorted in
/// street order, each once (empty for a blank text), or the first
/// [NumbersFailure].
Result<List<HouseNumber>, NumbersFailure> parseHouseNumbers(String text) {
  final numbers = <HouseNumber>{};
  final failure = _addItems(text, numbers);
  if (failure != null) return Err(failure);
  return Ok(_sorted(numbers));
}

/// Reads the manual street form: every number from [from] to [to] on
/// [sides], plus the [extras] (read like [parseHouseNumbers], kept whatever
/// the side: « En plus 12bis, 14ter »).
///
/// [from] and [to] are plain numbers; when one is blank the other is taken
/// alone, when both are the form gives the extras only, and when [from] is
/// above [to] they are swapped. Returns the numbers sorted, each once, or
/// the first [NumbersFailure].
Result<List<HouseNumber>, NumbersFailure> manualStreetNumbers({
  required String from,
  required String to,
  required Sides sides,
  required String extras,
}) {
  // `final` without a value: Dart checks that each path below assigns it
  // once before it is read.
  final int? first;
  switch (_bound(Bound.from, from)) {
    case Err(:final failure):
      return Err(failure);
    case Ok(:final value):
      first = value;
  }
  final int? last;
  switch (_bound(Bound.to, to)) {
    case Err(:final failure):
      return Err(failure);
    case Ok(:final value):
      last = value;
  }

  final numbers = <HouseNumber>{};
  final low = first ?? last;
  final high = last ?? first;
  if (low != null && high != null) {
    final failure = _addRange(low, high, sides, numbers);
    if (failure != null) return Err(failure);
  }
  final failure = _addItems(extras, numbers);
  if (failure != null) return Err(failure);
  return Ok(_sorted(numbers));
}

/// Commas, semicolons and line breaks all separate items.
final _separators = RegExp(r'[,;\n]');

/// A dash or an en dash: an item holding one is meant as a range.
final _dash = RegExp('[-–]');

/// Two runs of digits around one dash, spaces allowed around it.
final _range = RegExp(r'^(\d+)\s*[-–]\s*(\d+)$');

final _digits = RegExp(r'^\d+$');

/// Adds the numbers of each item of [text] to [numbers], or returns the
/// failure of the first wrong item (null when every item is right).
NumbersFailure? _addItems(String text, Set<HouseNumber> numbers) {
  for (final item in text.split(_separators)) {
    final token = item.trim();
    if (token.isEmpty) continue;
    final failure = token.contains(_dash)
        ? _addRangeItem(token, numbers)
        : _addNumberItem(token, numbers);
    if (failure != null) return failure;
  }
  return null;
}

NumbersFailure? _addNumberItem(String token, Set<HouseNumber> numbers) {
  switch (HouseNumber.parse(token)) {
    case Ok(:final value):
      numbers.add(value);
      return numbers.length > maxNumbersAtOnce ? const TooManyNumbers() : null;
    case Err(:final failure):
      return InvalidNumber(token, failure);
  }
}

NumbersFailure? _addRangeItem(String token, Set<HouseNumber> numbers) {
  final match = _range.firstMatch(token);
  // `match[1]!`: both groups always take part in a match.
  final start = match == null ? null : _plainNumber(match[1]!);
  final end = match == null ? null : _plainNumber(match[2]!);
  if (start == null || end == null) return InvalidRange(token);
  return _addRange(start, end, Sides.both, numbers);
}

/// Adds every number between [a] and [b] (in either order) on [sides] to
/// [numbers], unless that would make more than [maxNumbersAtOnce].
///
/// The range is counted before it is expanded, so `1-99999` is refused
/// without building 100 000 numbers; then the set is counted again, since
/// numbers already in it are not added twice.
NumbersFailure? _addRange(int a, int b, Sides sides, Set<HouseNumber> numbers) {
  final low = a < b ? a : b;
  final high = a < b ? b : a;
  final step = sides == Sides.both ? 1 : 2;
  final first = sides.includes(low) ? low : low + 1;
  final count = first > high ? 0 : (high - first) ~/ step + 1;
  if (count > maxNumbersAtOnce) return const TooManyNumbers();
  for (var number = first; number <= high; number += step) {
    numbers.add(HouseNumber.plain(number));
  }
  return numbers.length > maxNumbersAtOnce ? const TooManyNumbers() : null;
}

/// The number in a field of the manual form: null when the field is blank,
/// a failure when it is not a plain number in bounds.
Result<int?, NumbersFailure> _bound(Bound bound, String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const Ok(null);
  final number = _digits.hasMatch(trimmed) ? _plainNumber(trimmed) : null;
  if (number == null) return Err(InvalidBound(bound, trimmed));
  return Ok(number);
}

/// The value of [digits] when it is a house number (0 to
/// [HouseNumber.maxNumber]), or null. `tryParse` gives null when there are
/// more digits than an `int` holds.
int? _plainNumber(String digits) {
  final number = int.tryParse(digits);
  return number != null && number <= HouseNumber.maxNumber ? number : null;
}

List<HouseNumber> _sorted(Set<HouseNumber> numbers) =>
    List.unmodifiable(numbers.toList()..sort());
