import 'dart:math';

import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why a typed text cannot become a [JoinCode].
enum JoinCodeFailure {
  /// A character is not in [JoinCode.alphabet] (a `0`, an `O`, a `1`, an
  /// `I`, an `L`, punctuation other than the dash).
  invalidCharacter,

  /// Not [JoinCode.length] characters once the dash and spaces are set
  /// aside.
  wrongLength,
}

/// The secret that lets someone ask to join a tournée (PLAN §5.2, §8.1):
/// six characters such as `K7P2QX`, shown as `K7P-2QX` and in a QR code.
///
/// Knowing it is not enough to get in: it only sends a request that an
/// accepted member must approve. The tournée's number and centre de
/// secours are shown, never used to join.
final class JoinCode {
  const JoinCode._(this.value);

  /// The characters a code is made of: capitals and digits without the
  /// look-alikes `0`/`O` and `1`/`I`/`L`, so a code read aloud or from a
  /// photo is typed right. 31 characters, so 31⁶ ≈ 887 million codes.
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// The number of characters of a code.
  static const length = 6;

  /// Spaces and the dash, which a person may type or paste around and
  /// inside the code; they carry no meaning.
  static final _ignored = RegExp(r'[\s-]');

  /// A new code drawn from [random].
  ///
  /// The app passes `Random.secure()`, the operating system's secure source:
  /// a code made with the plain `Random()` could be predicted. Tests pass a
  /// scripted source so they know the code drawn.
  factory JoinCode.generate(Random random) => JoinCode._(
    String.fromCharCodes([
      for (var i = 0; i < length; i++)
        alphabet.codeUnitAt(random.nextInt(alphabet.length)),
    ]),
  );

  /// Reads a typed or stored code: case ignored, the dash and spaces set
  /// aside (`k7p-2qx` is `K7P2QX`). Fails with a [JoinCodeFailure]; a
  /// character outside the [alphabet] is reported before a wrong length,
  /// as it is the more precise message.
  static Result<JoinCode, JoinCodeFailure> parse(String text) {
    final code = text.replaceAll(_ignored, '').toUpperCase();
    // `split('')` walks the text one UTF-16 unit at a time: an emoji is
    // two units, neither in the alphabet, so it is refused all the same.
    if (code.split('').any((character) => !alphabet.contains(character))) {
      return const Err(JoinCodeFailure.invalidCharacter);
    }
    if (code.length != length) return const Err(JoinCodeFailure.wrongLength);
    return Ok(JoinCode._(code));
  }

  /// The six characters, upper case, without the dash: the form stored
  /// (`joinCodes/K7P2QX`, PLAN §6.2) and put in the QR code.
  final String value;

  /// The form shown to people: `K7P-2QX`, easier to read out in two halves.
  String get display => '${value.substring(0, 3)}-${value.substring(3)}';

  @override
  bool operator ==(Object other) => other is JoinCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'JoinCode($display)';
}
