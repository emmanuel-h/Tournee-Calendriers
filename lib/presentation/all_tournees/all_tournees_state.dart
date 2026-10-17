import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// What « Toutes les tournées » shows an admin (PLAN §5.12, AllTournees
/// mockup). `sealed`: the screen's `switch` handles each case.
sealed class AllTourneesState {
  const AllTourneesState();
}

/// The server is being asked.
final class AllTourneesLoading extends AllTourneesState {
  const AllTourneesLoading();
}

/// The server could not be reached (« Pas de réseau : la liste ne peut pas
/// être affichée. » and « Réessayer »).
final class AllTourneesOffline extends AllTourneesState {
  const AllTourneesOffline();
}

/// The server refused the list: the phone is no longer an admin's (« Vous
/// n'êtes plus administrateur. »).
final class AllTourneesNotAdmin extends AllTourneesState {
  const AllTourneesNotAdmin();
}

/// Every tournée of the app, grouped under its centre de secours.
final class AllTourneesShown extends AllTourneesState {
  AllTourneesShown(List<CentreGroup> groups)
    : groups = List.unmodifiable(groups);

  /// [overviews] grouped by station (the same station however written:
  /// `RescueCentreKey`), the stations in the order of their key (the name
  /// without « CS » / « CIS », French order), the tournées by number then
  /// year. A group is named as its first tournée names it.
  factory AllTourneesShown.of(List<TourneeOverview> overviews) {
    final sorted = [...overviews]
      ..sort((a, b) {
        final byNumber = a.number.value.compareTo(b.number.value);
        return byNumber != 0
            ? byNumber
            : a.campaign.value.compareTo(b.campaign.value);
      });
    // A map keeps the order keys were first added; they are sorted below.
    final byStation = <String, List<TourneeOverview>>{};
    for (final overview in sorted) {
      byStation.putIfAbsent(overview.centre.key.value, () => []).add(overview);
    }
    final stations = byStation.keys.toList()..sort();
    return AllTourneesShown([
      for (final station in stations)
        CentreGroup(
          centre: byStation[station]!.first.centre.name,
          rows: [
            for (final overview in byStation[station]!)
              OverviewRow(
                id: overview.id,
                number: overview.number.value,
                campaign: overview.campaign.value,
                members: overview.activeMembers,
                waitingRequests: overview.pendingRequests,
                iAmIn: overview.callerIsActive,
              ),
          ],
        ),
    ]);
  }

  final List<CentreGroup> groups;

  /// « Administrateur · 4 tournées ».
  int get count => groups.fold(0, (sum, group) => sum + group.rows.length);

  @override
  bool operator ==(Object other) =>
      other is AllTourneesShown && sameItems(other.groups, groups);

  @override
  int get hashCode => Object.hashAll(groups);
}

/// One centre de secours and its tournées (« CS GLEIZÉ »).
final class CentreGroup {
  CentreGroup({required this.centre, required List<OverviewRow> rows})
    : rows = List.unmodifiable(rows);

  /// The centre's name, as it was written.
  final String centre;
  final List<OverviewRow> rows;

  @override
  bool operator ==(Object other) =>
      other is CentreGroup &&
      other.centre == centre &&
      sameItems(other.rows, rows);

  @override
  int get hashCode => Object.hash(centre, Object.hashAll(rows));
}

/// One tournée: « Tournée 12 · 2026 » over « 3 membres · 1 demande en
/// attente » or « · vous en êtes membre ».
final class OverviewRow {
  const OverviewRow({
    required this.id,
    required this.number,
    required this.campaign,
    required this.members,
    required this.waitingRequests,
    required this.iAmIn,
  });

  /// Which tournée a tap opens.
  final TourneeId id;
  final int number;

  /// The year being worked on.
  final int campaign;

  /// Its active members; 0 reads « Aucun membre », in red.
  final int members;

  /// Requests waiting for an answer: a red dot.
  final int waitingRequests;

  /// The admin is an active member of it.
  final bool iAmIn;

  @override
  bool operator ==(Object other) =>
      other is OverviewRow &&
      other.id == id &&
      other.number == number &&
      other.campaign == campaign &&
      other.members == members &&
      other.waitingRequests == waitingRequests &&
      other.iAmIn == iAmIn;

  @override
  int get hashCode =>
      Object.hash(id, number, campaign, members, waitingRequests, iAmIn);
}
