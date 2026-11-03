import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';

/// What is left of a validated tournée (PLAN §5.13, §6.1): when it ran, how
/// many houses were visited, and its totals per payment method and of free
/// calendars.
///
/// **No member and no don**: this is all that leaves the phone, and the
/// whole secteur sees it in « Collecte ». A validated tournée is never
/// changed: an immutable value, equal to another with the same fields.
final class RoundSummary {
  const RoundSummary({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.housesVisited,
    required this.totals,
  });

  /// The tournée's own id, so its summary is stored once however often it
  /// is sent.
  final RoundId id;

  /// « Commencer une tournée », in UTC.
  final DateTime startedAt;

  /// « Valider la tournée », in UTC; always after [startedAt].
  final DateTime endedAt;

  /// The houses and doors made ✓ or ⊘ during the tournée (« 23 maisons »).
  final int housesVisited;

  final DonationTotals totals;

  @override
  bool operator ==(Object other) =>
      other is RoundSummary &&
      other.id == id &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.housesVisited == housesVisited &&
      other.totals == totals;

  @override
  int get hashCode =>
      Object.hash(id, startedAt, endedAt, housesVisited, totals);

  @override
  String toString() =>
      'RoundSummary(${id.value}, $startedAt → $endedAt, '
      '$housesVisited houses, $totals)';
}
