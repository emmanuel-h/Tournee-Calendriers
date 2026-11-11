import 'package:tournee_calendriers/domain/street/street_id.dart';

/// One row of Accueil's panel (« Rues », PLAN §5.14): a street that reads
/// ([StreetRow]) or one whose data cannot be read ([UnreadableStreetRow],
/// #149). `sealed`: a `switch` over the rows must handle both, so a new kind
/// of row breaks the build where it is drawn.
sealed class HomeRow {
  const HomeRow();

  /// Which street the row stands for.
  StreetId get id;
}

/// A street's name and how many of its doors are visited, done or refused
/// (« 31/403 »).
final class StreetRow extends HomeRow {
  const StreetRow({
    required this.id,
    required this.name,
    required this.done,
    required this.total,
  });

  /// Which street the row opens.
  @override
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

/// A street whose data cannot be read (PLAN §5.16): « ⚠ Rue Pasteur » over
/// « Illisible », or « Rue illisible » when its [name] cannot be read
/// either. Not in the totals; a tap opens its sheet.
final class UnreadableStreetRow extends HomeRow {
  const UnreadableStreetRow({required this.id, this.name});

  /// Which street the sheet would delete.
  @override
  final StreetId id;

  /// Its name, null when even the name cannot be read.
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is UnreadableStreetRow && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'UnreadableStreetRow(${id.value}, $name)';
}
