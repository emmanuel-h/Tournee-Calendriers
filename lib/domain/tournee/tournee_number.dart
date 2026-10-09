import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why a number cannot become a [TourneeNumber].
enum TourneeNumberFailure {
  /// The text is not made of digits only.
  notANumber,

  /// Not between 1 and [TourneeNumber.max].
  outOfRange,
}

/// The number of a tournée within its centre de secours (« Tournée 49 »,
/// PLAN §2, §5.2). With the `RescueCentre` it identifies the tournée across
/// the app: only one tournée 49 per station.
///
/// It is displayed, never used to join: that takes the join code.
final class TourneeNumber {
  const TourneeNumber._(this.value);

  /// The largest number accepted: four digits, far more than any station
  /// has rounds, while a slip of the finger such as `49999` is refused.
  static const max = 9999;

  static final _digits = RegExp(r'^\d+$');

  /// The tournée number [number], or [TourneeNumberFailure.outOfRange].
  static Result<TourneeNumber, TourneeNumberFailure> create(int number) {
    if (number < 1 || number > max) {
      return const Err(TourneeNumberFailure.outOfRange);
    }
    return Ok(TourneeNumber._(number));
  }

  /// Reads the « N° de tournée » field: digits only, spaces around and
  /// leading zeros ignored (`049` is 49).
  static Result<TourneeNumber, TourneeNumberFailure> parse(String text) {
    final digits = text.trim();
    // Checked first: `int.tryParse` would also read `+49` or `0x31`.
    if (!_digits.hasMatch(digits)) {
      return const Err(TourneeNumberFailure.notANumber);
    }
    // Null past the largest `int`, which is far out of range anyway.
    final number = int.tryParse(digits);
    if (number == null) return const Err(TourneeNumberFailure.outOfRange);
    return create(number);
  }

  final int value;

  @override
  bool operator ==(Object other) =>
      other is TourneeNumber && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TourneeNumber($value)';
}
