import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

/// Why a tournée of « Mes tournées » cannot be opened.
enum OpenSectorFailure {
  /// The phone does not know this tournée (left, refused, never joined).
  unknownSector,

  /// The member's request has not been accepted yet: nothing of the
  /// tournée can be read (PLAN §8.2).
  requestPending,
}

/// The tournées of the member on this phone (« Mes tournées », PLAN §5.3,
/// Q4) and the one the app shows, which it opens again at the next launch
/// (PLAN §4, §6.3). Kept on the phone only, never shared with the team.
///
/// Invariants, true of every `MySectors`:
/// - each tournée appears once, in the order the phone met them;
/// - the open tournée ([currentId]), when there is one, is in the list and
///   not a pending request.
///
/// Immutable: each change returns a new value.
final class MySectors {
  const MySectors._(this.sectors, this.currentId);

  /// A phone that knows no tournée yet: the first launch.
  static const none = MySectors._([], null);

  /// The member's tournées, open one included, pending requests too. The
  /// list cannot be modified (it throws an `UnsupportedError`).
  final List<SectorSummary> sectors;

  /// The tournée the app shows; null when none is open.
  final SectorId? currentId;

  /// The tournée the app shows; null when none is open.
  SectorSummary? get current => switch (currentId) {
    final id? => find(id),
    null => null,
  };

  /// The tournée [id], or null when the phone does not know it.
  SectorSummary? find(SectorId id) {
    for (final sector in sectors) {
      if (sector.id == id) return sector;
    }
    return null;
  }

  /// Keeps [sector]: a new one goes after the others, a known one is
  /// replaced in its place (its request accepted, a new campaign…). It does
  /// not open it: after « Créer » or « Rejoindre » the open tournée stays
  /// until the new one is ready (PLAN §5.3).
  ///
  /// Should the open tournée come back as a pending request, none is open
  /// any more.
  MySectors remember(SectorSummary sector) {
    final known = find(sector.id) != null;
    final kept = known
        ? [for (final other in sectors) other.id == sector.id ? sector : other]
        : [...sectors, sector];
    final stillOpen = !(currentId == sector.id && sector.isPending);
    return MySectors._(List.unmodifiable(kept), stillOpen ? currentId : null);
  }

  /// Makes the tournée [id] the one the app shows (tap in « Mes
  /// tournées »), one the member is in or one an admin visits. Fails when
  /// the phone does not know it or the member's request is still pending.
  Result<MySectors, OpenSectorFailure> open(SectorId id) {
    final sector = find(id);
    if (sector == null) return const Err(OpenSectorFailure.unknownSector);
    if (sector.isPending) return const Err(OpenSectorFailure.requestPending);
    return Ok(MySectors._(sectors, id));
  }

  /// Drops the tournée [id] (left, removed, request refused). When it was
  /// the open one, none is open any more: which tournée to show next is
  /// for the member to choose.
  MySectors forget(SectorId id) => MySectors._(
    List.unmodifiable(sectors.where((sector) => sector.id != id)),
    currentId == id ? null : currentId,
  );

  @override
  bool operator ==(Object other) =>
      other is MySectors &&
      other.currentId == currentId &&
      sameItems(other.sectors, sectors);

  @override
  int get hashCode => Object.hash(currentId, Object.hashAll(sectors));

  @override
  String toString() =>
      'MySectors(${sectors.map((sector) => sector.id.value).join(', ')}; '
      'open: ${currentId?.value})';
}
