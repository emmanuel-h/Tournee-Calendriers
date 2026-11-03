import 'package:tournee_calendriers/domain/street/street_id.dart';

/// One row of Accueil's panel (« Rues », PLAN §5.14): a street's name and
/// how many of its doors are visited, done or refused (« 31/403 »).
final class StreetRow {
  const StreetRow({
    required this.id,
    required this.name,
    required this.done,
    required this.total,
  });

  /// Which street the row opens.
  final StreetId id;
  final String name;

  /// Doors visited: done or refused (a building counts its dwellings), out
  /// of [total].
  final int done;
  final int total;

  /// Every door visited: the row shows « ✓ 8/8 » in green. A street without a
  /// door is never complete.
  bool get isComplete => total > 0 && done == total;

  /// How much of the progress bar is filled, 0 to 1.
  double get fraction => total == 0 ? 0 : done / total;

  @override
  bool operator ==(Object other) =>
      other is StreetRow &&
      other.id == id &&
      other.name == name &&
      other.done == done &&
      other.total == total;

  @override
  int get hashCode => Object.hash(id, name, done, total);
}
