import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why an (INSEE code, name) pair cannot become a [Commune].
enum CommuneFailure {
  /// The code is not five characters shaped like an INSEE commune code.
  invalidInseeCode,

  /// The name is empty or only spaces.
  blankName,
}

/// A French commune: its official INSEE code (`69264`) and its name
/// (`Villefranche-sur-Saône`), as the address base (BAN) gives them.
///
/// The code identifies the commune (two communes can share a name); the name
/// is what the screens show.
final class Commune {
  const Commune._(this.inseeCode, this.name);

  /// Two digits for the département (or `2A` / `2B` in Corsica), then three
  /// digits. Overseas codes (`97411`) have the same five-character shape.
  static final _inseeCodeShape = RegExp(r'^(\d{2}|2A|2B)\d{3}$');

  /// Builds the commune from [inseeCode] and [name], both trimmed; the code
  /// is upper-cased (`2a004` → `2A004`). Fails with a [CommuneFailure] when
  /// the code has the wrong shape or the name is blank.
  static Result<Commune, CommuneFailure> create({
    required String inseeCode,
    required String name,
  }) {
    final code = inseeCode.trim().toUpperCase();
    if (!_inseeCodeShape.hasMatch(code)) {
      return const Err(CommuneFailure.invalidInseeCode);
    }
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return const Err(CommuneFailure.blankName);
    return Ok(Commune._(code, trimmedName));
  }

  /// The five-character INSEE code, upper-case.
  final String inseeCode;

  /// The trimmed official name.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Commune && other.inseeCode == inseeCode && other.name == name;

  @override
  int get hashCode => Object.hash(inseeCode, name);

  @override
  String toString() => 'Commune($inseeCode, $name)';
}
