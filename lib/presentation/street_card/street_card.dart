import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/team_roster.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';

// The street card of « Ajouter des rues » and Accueil (PLAN §5.4, Pick
// mockup): what a street tapped on the map, or found by the search, is to
// the tournée, and what the member can do with it.

/// What the street card shows. `sealed`: the card has a layout for each
/// case, and the compiler checks that none is forgotten.
sealed class StreetCard {
  const StreetCard();
}

/// The street under the finger is being looked up (the BAN needs a
/// moment).
final class StreetCardLoading extends StreetCard {
  const StreetCardLoading();

  @override
  bool operator ==(Object other) => other is StreetCardLoading;

  @override
  int get hashCode => (StreetCardLoading).hashCode;
}

/// Why no street could be shown; the card says so and offers « Saisir une
/// rue à la main », which needs no network.
enum LookUpProblem {
  /// Offline: « Connexion nécessaire pour ajouter une rue ».
  noNetwork,

  /// The BAN knows no street there (a private road, a new estate).
  noStreetHere,

  /// The address service answered with an error.
  serviceError,
}

/// No street could be shown, for [problem].
final class StreetCardFailed extends StreetCard {
  const StreetCardFailed(this.problem);

  final LookUpProblem problem;

  @override
  bool operator ==(Object other) =>
      other is StreetCardFailed && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;
}

/// A street the tournée does not have: « 19 numéros · Pas encore dans la
/// tournée », « Ajouter et me l'attribuer », « Ajouter sans m'attribuer ».
final class StreetCardToAdd extends StreetCard {
  const StreetCardToAdd({
    required this.name,
    required this.commune,
    required this.numberCount,
    this.adding = false,
    this.addFailed = false,
  });

  final String name;
  final String commune;

  /// How many numbers the street would bring.
  final int numberCount;

  /// The street is being added (its road may take a while): the buttons
  /// wait.
  final bool adding;

  /// The address service gave numbers the street cannot take: nothing was
  /// added.
  final bool addFailed;

  @override
  bool operator ==(Object other) =>
      other is StreetCardToAdd &&
      other.name == name &&
      other.commune == commune &&
      other.numberCount == numberCount &&
      other.adding == adding &&
      other.addFailed == addFailed;

  @override
  int get hashCode =>
      Object.hash(name, commune, numberCount, adding, addFailed);
}

/// Who covers a street of the tournée, as its card tells it (PLAN §5.4).
enum StreetCoverage {
  /// Nobody: « Me l'attribuer » · « Ouvrir ».
  free,

  /// The member on the phone, maybe with others: « Ouvrir » · « Ne plus la
  /// faire ».
  mine,

  /// Others only: « La faire aussi » · « Ouvrir ».
  others,
}

/// A street of the tournée: its progress, who covers it, and the actions
/// of its [coverage].
final class StreetCardInTournee extends StreetCard {
  StreetCardInTournee({
    required this.id,
    required this.name,
    required this.commune,
    required this.done,
    required this.total,
    required this.coverage,
    required List<String> coveredBy,
  }) : coveredBy = List.unmodifiable(coveredBy);

  /// The card of [street], seen by the member [me]. The [team] names the
  /// others who cover it; null while it cannot be read (offline, never
  /// seen), when nobody is named.
  ///
  /// Only the assignees still in the [team] cover the street (#91): one
  /// whose every assignee left it is free, and anyone may take it. While
  /// the [team] is null, every assignee counts (see [TeamRoster]).
  factory StreetCardInTournee.of(
    Street street, {
    required MemberId me,
    required Tournee? team,
  }) {
    final assignees = TeamRoster.of(team, me: me).assigneesOf(street);
    final progress = street.progress;
    return StreetCardInTournee(
      id: street.id,
      name: street.name.text,
      commune: street.commune.name,
      done: progress.done,
      total: progress.total,
      coverage: assignees.isEmpty
          ? StreetCoverage.free
          : assignees.contains(me)
          ? StreetCoverage.mine
          : StreetCoverage.others,
      // In the team's order (oldest first), so the names never shuffle.
      // Someone no longer in the team is not among the [assignees].
      coveredBy: [
        for (final Member member in team?.members ?? const [])
          if (member.id != me && assignees.contains(member.id))
            member.name.text,
      ],
    );
  }

  /// The street « Ouvrir » opens, and the one « Me l'attribuer » takes.
  final StreetId id;
  final String name;
  final String commune;

  /// Doors done, out of [total].
  final int done;
  final int total;

  final StreetCoverage coverage;

  /// The first names of the teammates who cover the street, the member on
  /// the phone left out: « avec Paul » when [coverage] is
  /// [StreetCoverage.mine], « Faite par Paul » when it is
  /// [StreetCoverage.others]. Read-only; may be empty even then (the team
  /// not read yet).
  final List<String> coveredBy;

  @override
  bool operator ==(Object other) =>
      other is StreetCardInTournee &&
      other.id == id &&
      other.name == name &&
      other.commune == commune &&
      other.done == done &&
      other.total == total &&
      other.coverage == coverage &&
      sameItems(other.coveredBy, coveredBy);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    commune,
    done,
    total,
    coverage,
    Object.hashAll(coveredBy),
  );

  @override
  String toString() =>
      'StreetCardInTournee(${id.value}, $name, $done/$total, $coverage, '
      '$coveredBy)';
}
