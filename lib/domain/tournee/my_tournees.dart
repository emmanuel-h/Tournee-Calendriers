import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

/// Why a tournée of « Mes tournées » cannot be opened.
enum OpenTourneeFailure {
  /// The phone does not know this tournée (left, refused, never joined).
  unknownTournee,

  /// The member's request has not been accepted yet: nothing of the
  /// tournée can be read (PLAN §8.2).
  requestPending,
}

/// The tournées of the member on this phone (« Mes tournées », PLAN §5.3,
/// Q4) and the one the app shows, which it opens again at the next launch
/// (PLAN §4, §6.3). Kept on the phone only, never shared with the team.
///
/// Invariants, true of every `MyTournees`:
/// - each tournée appears once, in the order the phone met them;
/// - the open tournée ([currentId]), when there is one, is in the list and
///   not a pending request.
///
/// Immutable: each change returns a new value.
final class MyTournees {
  const MyTournees._(this.tournees, this.currentId);

  /// A phone that knows no tournée yet: the first launch.
  static const none = MyTournees._([], null);

  /// The member's tournées, open one included, pending requests too. The
  /// list cannot be modified (it throws an `UnsupportedError`).
  final List<TourneeSummary> tournees;

  /// The tournée the app shows; null when none is open.
  final TourneeId? currentId;

  /// The tournée the app shows; null when none is open.
  TourneeSummary? get current => switch (currentId) {
    final id? => find(id),
    null => null,
  };

  /// The tournée [id], or null when the phone does not know it.
  TourneeSummary? find(TourneeId id) {
    for (final tournee in tournees) {
      if (tournee.id == id) return tournee;
    }
    return null;
  }

  /// Keeps [tournee]: a new one goes after the others, a known one is
  /// replaced in its place (its request accepted, a new campaign…). It does
  /// not open it: after « Créer » or « Rejoindre » the open tournée stays
  /// until the new one is ready (PLAN §5.3).
  ///
  /// Should the open tournée come back as a pending request, none is open
  /// any more.
  MyTournees remember(TourneeSummary tournee) {
    final known = find(tournee.id) != null;
    final kept = known
        ? [
            for (final other in tournees)
              other.id == tournee.id ? tournee : other,
          ]
        : [...tournees, tournee];
    final stillOpen = !(currentId == tournee.id && tournee.isPending);
    return MyTournees._(List.unmodifiable(kept), stillOpen ? currentId : null);
  }

  /// Makes the tournée [id] the one the app shows (tap in « Mes
  /// tournées »). Fails when the phone does not know it or the member's
  /// request is still pending.
  Result<MyTournees, OpenTourneeFailure> open(TourneeId id) {
    final tournee = find(id);
    if (tournee == null) return const Err(OpenTourneeFailure.unknownTournee);
    if (tournee.isPending) return const Err(OpenTourneeFailure.requestPending);
    return Ok(MyTournees._(tournees, id));
  }

  /// Drops the tournée [id] (left, removed, request refused). When it was
  /// the open one, none is open any more: which tournée to show next is
  /// for the member to choose.
  MyTournees forget(TourneeId id) => MyTournees._(
    List.unmodifiable(tournees.where((tournee) => tournee.id != id)),
    currentId == id ? null : currentId,
  );

  @override
  bool operator ==(Object other) =>
      other is MyTournees &&
      other.currentId == currentId &&
      sameItems(other.tournees, tournees);

  @override
  int get hashCode => Object.hash(currentId, Object.hashAll(tournees));

  @override
  String toString() =>
      'MyTournees(${tournees.map((tournee) => tournee.id.value).join(', ')}; '
      'open: ${currentId?.value})';
}
