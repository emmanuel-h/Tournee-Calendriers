import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

/// Where a tournée of « Mes secteurs » stands for the member.
enum SectorRowStatus {
  /// The tournée the app shows (● and ✓ in the sheet).
  open,

  /// One of the member's tournées, not shown now: a tap opens it.
  closed,

  /// The member's request waits for an answer (« votre demande est en
  /// attente »): it cannot be opened.
  pending,
}

/// One row of « Mes secteurs » (« Tournée 49 · 2026 », « CS
/// Villefranche »).
final class SectorRow {
  const SectorRow({
    required this.id,
    required this.number,
    required this.campaign,
    required this.centre,
    required this.status,
    this.waitingRequests = 0,
    this.visited = false,
  });

  /// Which tournée the row opens.
  final SectorId id;
  final int number;

  /// The year being worked on.
  final int campaign;

  /// The centre de secours, as it was written.
  final String centre;
  final SectorRowStatus status;

  /// The join requests waiting in the tournée for an answer from its
  /// members (« · 1 demande en attente » and a dot, Switcher mockup).
  /// Followed only for the tournées not open: the open one's show on
  /// Accueil's title.
  final int waitingRequests;

  /// An admin opened it without being in its team (PLAN §5.12): a shield
  /// instead of the ring, « CS … · administrateur ».
  final bool visited;

  @override
  bool operator ==(Object other) =>
      other is SectorRow &&
      other.id == id &&
      other.number == number &&
      other.campaign == campaign &&
      other.centre == centre &&
      other.status == status &&
      other.waitingRequests == waitingRequests &&
      other.visited == visited;

  @override
  int get hashCode => Object.hash(
    id,
    number,
    campaign,
    centre,
    status,
    waitingRequests,
    visited,
  );
}

/// What « Mes secteurs » and the title of the start screen show (PLAN
/// §5.3). Immutable: the notifier replaces it as a whole.
final class MySectorsState {
  MySectorsState({required List<SectorRow> rows, required this.current})
    : rows = List.unmodifiable(rows);

  /// The rows of [mine], in the order the phone met the tournées: opening
  /// another one does not move them under the finger. [waiting] counts the
  /// requests waiting in some of them, by tournée; none for the others.
  factory MySectorsState.of(
    MySectors mine, {
    Map<SectorId, int> waiting = const {},
  }) => MySectorsState(
    rows: [
      for (final sector in mine.sectors)
        SectorRow(
          id: sector.id,
          number: sector.number.value,
          campaign: sector.campaign.value,
          centre: sector.centre.name,
          status: sector.id == mine.currentId
              ? SectorRowStatus.open
              : sector.isPending
              ? SectorRowStatus.pending
              : SectorRowStatus.closed,
          waitingRequests: waiting[sector.id] ?? 0,
          visited: sector.isVisiting,
        ),
    ],
    current: mine.current,
  );

  /// Every tournée of the member, open one and pending requests included.
  final List<SectorRow> rows;

  /// The tournée the app shows, null when none is open: the start screen
  /// then keeps the app's name as its title.
  final SectorSummary? current;

  @override
  bool operator ==(Object other) =>
      other is MySectorsState &&
      other.current == current &&
      sameItems(other.rows, rows);

  @override
  int get hashCode => Object.hash(current, Object.hashAll(rows));
}
