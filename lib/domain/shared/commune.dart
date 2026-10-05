import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why an (INSEE code, name) pair cannot become a [Commune].
enum CommuneFailure {
  /// The code is not a valid [InseeCode].
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

  /// Builds the commune from [inseeCode] (read as [InseeCode.parse] reads
  /// it) and [name], trimmed. Fails with a [CommuneFailure] when the code
  /// has the wrong shape or the name is blank.
  static Result<Commune, CommuneFailure> create({
    required String inseeCode,
    required String name,
  }) {
    final InseeCode code;
    switch (InseeCode.parse(inseeCode)) {
      case Err():
        return const Err(CommuneFailure.invalidInseeCode);
      case Ok(:final value):
        code = value;
    }
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return const Err(CommuneFailure.blankName);
    return Ok(Commune._(code, trimmedName));
  }

  final InseeCode inseeCode;

  /// The trimmed official name.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Commune && other.inseeCode == inseeCode && other.name == name;

  @override
  int get hashCode => Object.hash(inseeCode, name);

  @override
  String toString() => 'Commune(${inseeCode.value}, $name)';
}
