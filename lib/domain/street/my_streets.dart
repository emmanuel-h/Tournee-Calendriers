import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/street.dart';

/// The streets of a tournée as one member sees them on Accueil (PLAN §5.3):
/// « Mes rues », the streets they cover (`Street.assignees`), and the
/// others, free or covered by someone else. Only [member] decides the
/// split, so it needs no team: a street held only by someone who left the
/// team is among the others, and « libre » where that matters (see
/// `TeamRoster`).
///
/// Streets in the Corbeille are left out of everything, the team's
/// progress included.
final class MyStreets {
  const MyStreets._({
    required this.all,
    required this.mine,
    required this.others,
  });

  /// No street at all: before the streets are read, or once they can no
  /// longer be.
  static const none = MyStreets._(all: [], mine: [], others: []);

  /// [streets] seen by [member]. Each list keeps the order of [streets].
  factory MyStreets.of(Iterable<Street> streets, MemberId member) {
    final shown = [
      for (final street in streets)
        if (!street.isDeleted) street,
    ];
    return MyStreets._(
      all: List.unmodifiable(shown),
      mine: List.unmodifiable(
        shown.where((street) => street.assignees.contains(member)),
      ),
      others: List.unmodifiable(
        shown.where((street) => !street.assignees.contains(member)),
      ),
    );
  }

  /// Every street of the tournée. The lists cannot be modified.
  final List<Street> all;

  /// « Mes rues »: the streets the member covers.
  final List<Street> mine;

  /// The streets the member does not cover.
  final List<Street> others;

  /// The doors of « Mes rues » (« Mes rues · 43/62 »).
  Progress get myProgress => _sum(mine);

  /// The doors of the whole tournée (« Équipe : 41 % »).
  Progress get teamProgress => _sum(all);

  static Progress _sum(Iterable<Street> streets) =>
      streets.fold(Progress.empty, (sum, street) => sum + street.progress);
}
