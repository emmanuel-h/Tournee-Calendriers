import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

/// Where a tournée of « Mes tournées » stands for the member.
enum TourneeRowStatus {
  /// The tournée the app shows (● and ✓ in the sheet).
  open,

  /// One of the member's tournées, not shown now: a tap opens it.
  closed,

  /// The member's request waits for an answer (« votre demande est en
  /// attente »): it cannot be opened.
  pending,
}

/// One row of « Mes tournées » (« Tournée 49 · 2026 », « CS
/// Villefranche »).
final class TourneeRow {
  const TourneeRow({
    required this.id,
    required this.number,
    required this.campaign,
    required this.centre,
    required this.status,
  });

  /// Which tournée the row opens.
  final TourneeId id;
  final int number;

  /// The year being worked on.
  final int campaign;

  /// The centre de secours, as it was written.
  final String centre;
  final TourneeRowStatus status;

  @override
  bool operator ==(Object other) =>
      other is TourneeRow &&
      other.id == id &&
      other.number == number &&
      other.campaign == campaign &&
      other.centre == centre &&
      other.status == status;

  @override
  int get hashCode => Object.hash(id, number, campaign, centre, status);
}

/// What « Mes tournées » and the title of the start screen show (PLAN
/// §5.3). Immutable: the notifier replaces it as a whole.
final class MyTourneesState {
  MyTourneesState({required List<TourneeRow> rows, required this.current})
    : rows = List.unmodifiable(rows);

  /// The rows of [mine], in the order the phone met the tournées: opening
  /// another one does not move them under the finger.
  factory MyTourneesState.of(MyTournees mine) => MyTourneesState(
    rows: [
      for (final tournee in mine.tournees)
        TourneeRow(
          id: tournee.id,
          number: tournee.number.value,
          campaign: tournee.campaign.value,
          centre: tournee.centre.name,
          status: tournee.id == mine.currentId
              ? TourneeRowStatus.open
              : tournee.isPending
              ? TourneeRowStatus.pending
              : TourneeRowStatus.closed,
        ),
    ],
    current: mine.current,
  );

  /// Every tournée of the member, open one and pending requests included.
  final List<TourneeRow> rows;

  /// The tournée the app shows, null when none is open: the start screen
  /// then keeps the app's name as its title.
  final TourneeSummary? current;

  @override
  bool operator ==(Object other) =>
      other is MyTourneesState &&
      other.current == current &&
      sameItems(other.rows, rows);

  @override
  int get hashCode => Object.hash(current, Object.hashAll(rows));
}
