import 'package:tournee_calendriers/domain/street/street_id.dart';

/// One row of « Mes rues »: a street's name and how many of its doors are
/// done (« 31/403 »).
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

  /// Doors done (a building counts its dwellings), out of [total].
  final int done;
  final int total;

  /// Every door done: the row shows « ✓ 8/8 » in green. A street without a
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

/// What the « Mes rues » start screen shows (PLAN §5.0). Immutable: the
/// notifier replaces it as a whole, and the screen redraws.
final class StreetListState {
  StreetListState({
    required this.loading,
    required this.streetCount,
    required List<String> communes,
    required List<StreetRow> rows,
    required this.filter,
  }) : communes = List.unmodifiable(communes),
       rows = List.unmodifiable(rows);

  /// True until the streets have been read from the phone once.
  final bool loading;

  /// How many streets are on the phone, filter or not (« Mes rues · 3 »).
  final int streetCount;

  /// The communes of those streets, each once, in French order.
  final List<String> communes;

  /// The streets the filter keeps, in French order of their names.
  final List<StreetRow> rows;

  /// The text of the « Filtrer les rues… » field.
  final String filter;

  /// No street imported yet: the screen shows its first-launch message.
  bool get isEmpty => !loading && streetCount == 0;
}
