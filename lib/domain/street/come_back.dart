import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// Why a hint cannot go with a [ComeBack].
enum ComeBackFailure {
  /// More than [ComeBack.maxHintLength] characters once trimmed.
  hintTooLong,
}

/// What goes with a « repasser »: the optional [hint] such as « après 19h »
/// (PLAN §2).
///
/// « Repasser » is a status of its own ([VisitStatus.comeBack]): a house or
/// a door has a `ComeBack` exactly when it has that status (see
/// [ComeBack.keptBy]). A building, which has no status of its own, may
/// carry one for itself (« Repasser » under its grid). The hint is trimmed
/// and holds at most [maxHintLength] characters as counted by
/// [characterCount].
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

  /// The come-back a house or a door with [status] keeps of [comeBack]:
  /// only a door « repasser » has one, without hint unless one is given;
  /// any other status has none. The `House` and `Dwelling` factories run
  /// it, so no house is ever « personne » and « repasser » at once.
  static ComeBack? keptBy(VisitStatus status, ComeBack? comeBack) =>
      status == VisitStatus.comeBack ? comeBack ?? withoutHint : null;

  /// The trimmed hint; empty when none was given.
  final String hint;

  @override
  bool operator ==(Object other) => other is ComeBack && other.hint == hint;

  @override
  int get hashCode => hint.hashCode;

  @override
  String toString() => 'ComeBack($hint)';
}
