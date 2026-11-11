import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why a number cannot become a [SectorNumber].
enum SectorNumberFailure {
  /// The text is not made of digits only.
  notANumber,

  /// Not between 1 and [SectorNumber.max].
  outOfRange,
}

/// The number of a secteur within its centre de secours (« Secteur 49 »,
/// PLAN §2, §5.2). With the `RescueCentre` it identifies the secteur across
/// the app: only one secteur 49 per station.
///
/// It is displayed, never used to join: that takes the join code.
final class SectorNumber {
  const SectorNumber._(this.value);

  /// The largest number accepted: four digits, far more than any station
  /// has rounds, while a slip of the finger such as `49999` is refused.
  static const max = 9999;

  static final _digits = RegExp(r'^\d+$');

  /// The secteur number [number], or [SectorNumberFailure.outOfRange].
  static Result<SectorNumber, SectorNumberFailure> create(int number) {
    if (number < 1 || number > max) {
      return const Err(SectorNumberFailure.outOfRange);
    }
    return Ok(SectorNumber._(number));
  }

  /// Reads the « N° de secteur » field: digits only, spaces around and
  /// leading zeros ignored (`049` is 49).
  static Result<SectorNumber, SectorNumberFailure> parse(String text) {
    final digits = text.trim();
    // Checked first: `int.tryParse` would also read `+49` or `0x31`.
    if (!_digits.hasMatch(digits)) {
      return const Err(SectorNumberFailure.notANumber);
    }
    // Null past the largest `int`, which is far out of range anyway.
    final number = int.tryParse(digits);
    if (number == null) return const Err(SectorNumberFailure.outOfRange);
    return create(number);
  }

  final int value;

  @override
  bool operator ==(Object other) =>
      other is SectorNumber && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SectorNumber($value)';
}
