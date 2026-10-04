import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';

/// Why a hint cannot go with a [ComeBack].
enum ComeBackFailure {
  /// More than [ComeBack.maxHintLength] characters once trimmed.
  hintTooLong,
}

/// « Repasser »: the residents asked the team to come back later, with an
/// optional [hint] such as « après 19h » (PLAN §2).
///
/// A house either has a `ComeBack` or not; the flag is the presence of the
/// value, the hint is its content. The hint is trimmed and holds at most
/// [maxHintLength] characters as counted by [characterCount].
final class ComeBack {
  const ComeBack._(this.hint);

  /// « Repasser » with nothing more said.
  static const withoutHint = ComeBack._('');

  /// The longest hint, in characters: a short time or day, not a second
  /// note. The security rules enforce the same limit (PLAN §8.2).
  static const maxHintLength = 50;

  /// Builds the « repasser » flag with [hint] once trimmed (a blank hint
  /// means none), or fails with [ComeBackFailure.hintTooLong].
  static Result<ComeBack, ComeBackFailure> create(String hint) {
    final trimmed = hint.trim();
    if (characterCount(trimmed) > maxHintLength) {
      return const Err(ComeBackFailure.hintTooLong);
    }
    return Ok(ComeBack._(trimmed));
  }

  /// The trimmed hint; empty when none was given.
  final String hint;

  @override
  bool operator ==(Object other) => other is ComeBack && other.hint == hint;

  @override
  int get hashCode => hint.hashCode;

  @override
  String toString() => 'ComeBack($hint)';
}
