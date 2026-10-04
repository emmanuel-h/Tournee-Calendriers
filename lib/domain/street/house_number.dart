import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why a text or a (number, suffix) pair cannot become a [HouseNumber].
enum HouseNumberFailure {
  /// Nothing was typed.
  empty,

  /// The text does not start with a number (`bis`, `A3`, `-3`).
  malformed,

  /// The number is below zero (only possible through [HouseNumber.create]).
  negativeNumber,

  /// The number is above [HouseNumber.maxNumber].
  numberTooLarge,

  /// The suffix is not one word of ASCII letters and digits starting with a
  /// letter (`12 3`, `12-bis`, `12é`).
  invalidSuffix,

  /// The suffix has more than [HouseNumber.maxSuffixLength] characters.
  suffixTooLong,
}

/// The number of a house in its street: an integer [number] and an optional
/// [suffix] (`12`, `12bis`, `3A`).
///
/// Two numbers written differently but meaning the same thing (`12 BIS`,
/// `12bis`) are equal, and their [label] is the same: the label is both what
/// the tile shows and the house's key in storage (PLAN §6.2).
///
/// `Comparable` gives the order of a side of the street (PLAN §5.6), so a
/// list of numbers sorts with a plain `list.sort()`:
/// `3 < 3bis < 3ter < 3quater < 3A < 4`.
final class HouseNumber implements Comparable<HouseNumber> {
  const HouseNumber._(this.number, this.suffix);

  /// The largest number: the national address base (BAN) numbers houses
  /// with at most five digits.
  static const maxNumber = 99999;

  /// The longest suffix. The longest Latin multiplicative French addresses
  /// use, « quaterdecies », has 12 letters; 16 leaves room for unusual but
  /// real suffixes from the BAN, which must never be refused.
  static const maxSuffixLength = 16;

  /// The Latin multiplicatives, in their order: `12bis` comes before
  /// `12ter`. Any other suffix (`A`, `B`…) comes after all of them.
  static const _latinMultiplicatives = [
    'bis',
    'ter',
    'quater',
    'quinquies',
    'sexies',
    'septies',
    'octies',
    'nonies',
    'decies',
  ];

  /// Digits, then anything; the suffix part is checked by [create].
  /// `\s*` lets « 12 bis » and « 12bis » mean the same.
  static final _digitsThenRest = RegExp(r'^(\d+)\s*(.*)$');

  /// A canonical suffix: lowercase ASCII letters and digits, letter first,
  /// so `12 3` is not read as « 12 » with the suffix « 3 ».
  static final _suffixShape = RegExp(r'^[a-z][a-z0-9]*$');

  /// Reads a number typed by a person: `12`, `12bis`, `12 bis`, `12BIS`,
  /// `12 B`, `3A`. Spaces around the text and between the number and the
  /// suffix are ignored, and so are the case and leading zeros.
  ///
  /// Returns an [Err] with a [HouseNumberFailure] when the text is not a
  /// house number.
  static Result<HouseNumber, HouseNumberFailure> parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const Err(HouseNumberFailure.empty);

    final match = _digitsThenRest.firstMatch(trimmed);
    if (match == null) return const Err(HouseNumberFailure.malformed);

    // `match[1]` is the first group of the pattern; the `!` says it is never
    // null (the group always takes part in a match). `tryParse` returns null
    // only when the digits are too many for an `int`.
    final number = int.tryParse(match[1]!);
    if (number == null) return const Err(HouseNumberFailure.numberTooLarge);

    return create(number, suffix: match[2]);
  }

  /// Builds a number from its parts, as the address base (BAN) gives them:
  /// `numero` and `suffixe` (null, or a word such as `bis` or `a`).
  ///
  /// The suffix is trimmed and lower-cased; an empty or blank suffix means
  /// none. Returns an [Err] with a [HouseNumberFailure] when a part is out
  /// of bounds.
  static Result<HouseNumber, HouseNumberFailure> create(
    int number, {
    String? suffix,
  }) {
    if (number < 0) return const Err(HouseNumberFailure.negativeNumber);
    if (number > maxNumber) return const Err(HouseNumberFailure.numberTooLarge);

    final canonical = suffix?.trim().toLowerCase() ?? '';
    if (canonical.isEmpty) return Ok(HouseNumber._(number, null));
    if (!_suffixShape.hasMatch(canonical)) {
      return const Err(HouseNumberFailure.invalidSuffix);
    }
    if (canonical.length > maxSuffixLength) {
      return const Err(HouseNumberFailure.suffixTooLong);
    }
    return Ok(HouseNumber._(number, canonical));
  }

  /// The integer part, from 0 to [maxNumber].
  final int number;

  /// The suffix in lowercase (`bis`, `a`), as the BAN writes it; null when
  /// there is none.
  final String? suffix;

  /// The canonical written form: Latin multiplicatives in lowercase and
  /// glued (`12bis`), other suffixes in uppercase (`3A`).
  String get label => switch (suffix) {
    null => '$number',
    // A `when` guard: this case matches only if the condition holds.
    final multiplicative when _latinMultiplicatives.contains(multiplicative) =>
      '$number$multiplicative',
    final other => '$number${other.toUpperCase()}',
  };

  /// Whether the house is on the odd side; the suffix plays no part.
  bool get isOdd => number.isOdd;

  /// Whether the house is on the even side (0 included).
  bool get isEven => number.isEven;

  /// Where the suffix sorts among the numbers sharing the same integer part:
  /// 0 without suffix, then each Latin multiplicative in its order, then
  /// every other suffix with the same rank (they sort alphabetically).
  int get _suffixRank => switch (suffix) {
    null => 0,
    final multiplicative when _latinMultiplicatives.contains(multiplicative) =>
      _latinMultiplicatives.indexOf(multiplicative) + 1,
    _ => _latinMultiplicatives.length + 1,
  };

  @override
  int compareTo(HouseNumber other) {
    final byNumber = number.compareTo(other.number);
    if (byNumber != 0) return byNumber;
    final byRank = _suffixRank.compareTo(other._suffixRank);
    if (byRank != 0) return byRank;
    return (suffix ?? '').compareTo(other.suffix ?? '');
  }

  @override
  bool operator ==(Object other) =>
      other is HouseNumber && other.number == number && other.suffix == suffix;

  @override
  int get hashCode => Object.hash(number, suffix);

  @override
  String toString() => 'HouseNumber($label)';
}
