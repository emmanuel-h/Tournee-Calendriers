import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why a text cannot become an [InseeCode].
enum InseeCodeFailure {
  /// Not five characters shaped like an INSEE commune code.
  badShape,
}

/// The official code of a French commune (`69264` for
/// Villefranche-sur-Saône), which identifies it: two communes can share a
/// name, never a code. The address base (BAN) lists a commune's streets by
/// it.
final class InseeCode {
  const InseeCode._(this.value);

  /// Two digits for the département (or `2A` / `2B` in Corsica), then three
  /// digits. Overseas codes (`97411`) have the same five-character shape.
  static final _shape = RegExp(r'^(\d{2}|2A|2B)\d{3}$');

  /// Reads [text], trimmed and upper-cased (`2a004` → `2A004`), or fails
  /// with [InseeCodeFailure.badShape].
  static Result<InseeCode, InseeCodeFailure> parse(String text) {
    final code = text.trim().toUpperCase();
    if (!_shape.hasMatch(code)) return const Err(InseeCodeFailure.badShape);
    return Ok(InseeCode._(code));
  }

  /// The five characters, upper-case.
  final String value;

  @override
  bool operator ==(Object other) => other is InseeCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'InseeCode($value)';
}
