import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/corbeille.dart';
import 'package:tournee_calendriers/presentation/shared/recent_time.dart';

/// What the Corbeille shows (PLAN §5.11), and its count in Équipe
/// (« Corbeille · 2 éléments »). Immutable: the notifier replaces it.
final class CorbeilleState {
  CorbeilleState({required this.loading, required List<CorbeilleRow> rows})
    : rows = List.unmodifiable(rows);

  /// Before the streets are read: nothing to show yet, not even « vide ».
  static final waiting = CorbeilleState(loading: true, rows: const []);

  final bool loading;

  /// The deleted streets and removed numbers, the latest first.
  final List<CorbeilleRow> rows;

  int get count => rows.length;

  @override
  bool operator ==(Object other) =>
      other is CorbeilleState &&
      other.loading == loading &&
      sameItems(other.rows, rows);

  @override
  int get hashCode => Object.hash(loading, Object.hashAll(rows));
}

/// One deleted street or number: « Rue Gambetta · 22 numéros · supprimée
/// par Paul · hier », and what « Restaurer » brings back.
final class CorbeilleRow {
  const CorbeilleRow({
    required this.item,
    required this.removedBy,
    required this.removedAt,
  });

  /// The street or number, with its street's name.
  final CorbeilleItem item;

  /// The first name of who deleted it; null when they are no longer in the
  /// team (or no tournée is open), which the screen words neutrally.
  final String? removedBy;
  final RecentTime removedAt;

  @override
  bool operator ==(Object other) =>
      other is CorbeilleRow &&
      other.item == item &&
      other.removedBy == removedBy &&
      other.removedAt == removedAt;

  @override
  int get hashCode => Object.hash(item, removedBy, removedAt);
}
