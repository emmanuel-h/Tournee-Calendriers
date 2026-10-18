import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// One version of the app as « Nouveautés » shows it (PLAN §5.9): its
/// number, the day it came out and what it brings, in short lines for the
/// members (not commit messages).
///
/// The lines are a function of the translations because every French text
/// lives in `app_fr.arb`: the list below only says which messages belong to
/// which version.
final class Release {
  const Release({
    required this.version,
    required this.date,
    required this.notes,
  });

  /// As in `pubspec.yaml`: « 0.1.0 ».
  final String version;

  /// The day the version came out; only the day counts.
  final DateTime date;

  /// What changed, one line each, in the order shown.
  final List<String> Function(AppLocalizations l10n) notes;
}

/// Every version, newest first. It ships inside the app, so « Nouveautés »
/// works offline. Each release (#37) adds its entry at the top, with the
/// day it is published, and its lines to `app_fr.arb`.
final shippedReleases = [
  Release(
    version: '0.5.0',
    date: DateTime(2026, 10, 18),
    notes: (l10n) => [
      l10n.release050Map,
      l10n.release050AddStreets,
      l10n.release050Assignees,
      l10n.release050Tries,
    ],
  ),
  Release(
    version: '0.4.0',
    date: DateTime(2026, 10, 17),
    notes: (l10n) => [l10n.release040LastChangeBy, l10n.release040AdminRevoked],
  ),
  Release(
    version: '0.3.0',
    date: DateTime(2026, 10, 17),
    notes: (l10n) => [l10n.release030DeviceId],
  ),
  Release(
    version: '0.2.0',
    date: DateTime(2026, 10, 17),
    notes: (l10n) => [
      l10n.release020Admins,
      l10n.release020AllTournees,
      l10n.release020Team,
      l10n.release020DeviceId,
    ],
  ),
  Release(
    version: '0.1.0',
    date: DateTime(2026, 10, 16),
    notes: (l10n) => [l10n.release010First],
  ),
];

/// The versions « Nouveautés » lists: [shippedReleases]. A provider only so
/// a widget test can show other versions (`overrideWithValue`) and prove
/// the screen keeps their order.
final changelogProvider = Provider<List<Release>>((ref) => shippedReleases);
