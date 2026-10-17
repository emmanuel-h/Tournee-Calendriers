import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/my_streets.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// A street of Villefranche-sur-Saône with one door per status of
/// [statuses], covered by [assignees].
Street _street(
  String id,
  String name, {
  Set<String> assignees = const {},
  List<VisitStatus> statuses = const [],
}) => valueOf(
  Street.create(
    id: StreetId(id),
    name: name,
    commune: villefranche,
    assignees: {for (final member in assignees) MemberId(member)},
    houses: [
      for (final (index, status) in statuses.indexed)
        House(number: n('${index + 1}'), status: status),
    ],
  ),
);

/// The progress of one door per status of [statuses].
Progress _progress(List<VisitStatus> statuses) =>
    statuses.fold(Progress.empty, (sum, status) => sum + Progress.of(status));

const _done = VisitStatus.done;
const _toDo = VisitStatus.toDo;
const _nobody = VisitStatus.nobodyHome;

void main() {
  // Rue Nationale: Léa's, 1 of 3 done. Rue de la Paix: nobody's, 2 of 2.
  // Rue Pierre Morin: Léa's and Paul's, 0 of 1. Rue Victor Hugo: Paul's,
  // 1 of 2.
  final nationale = _street(
    'nationale',
    'Rue Nationale',
    assignees: {'lea'},
    statuses: [_done, _toDo, _nobody],
  );
  final paix = _street('paix', 'Rue de la Paix', statuses: [_done, _done]);
  final morin = _street(
    'morin',
    'Rue Pierre Morin',
    assignees: {'lea', 'paul'},
    statuses: [_toDo],
  );
  final hugo = _street(
    'hugo',
    'Rue Victor Hugo',
    assignees: {'paul'},
    statuses: [_done, _toDo],
  );
  final streets = [nationale, paix, morin, hugo];

  test('should keep the streets the member covers, in the order given', () {
    final mine = MyStreets.of(streets, lea);

    expect(mine.mine, [nationale, morin]);
  });

  test('should keep the others, free or covered by someone else, in the '
      'order given', () {
    final mine = MyStreets.of(streets, lea);

    expect(mine.others, [paix, hugo]);
  });

  test('should hold every street in the order given', () {
    expect(MyStreets.of(streets, lea).all, streets);
  });

  test('should add up the doors of the member\'s streets only', () {
    final mine = MyStreets.of(streets, lea);

    expect(mine.myProgress, _progress([_done, _toDo, _nobody, _toDo]));
  });

  test('should add up the doors of every street for the team', () {
    final mine = MyStreets.of(streets, paul);

    expect(
      mine.teamProgress,
      _progress([_done, _toDo, _nobody, _done, _done, _toDo, _done, _toDo]),
    );
  });

  test('should put every street among the others when the member covers '
      'none', () {
    final mine = MyStreets.of(streets, MemberId('zoe'));

    expect(mine.mine, isEmpty);
    expect(mine.others, streets);
    expect(mine.myProgress, Progress.empty);
  });

  test('should leave out the streets in the Corbeille', () {
    final (deleted, _) = _street(
      'gare',
      'Rue de la Gare',
      assignees: {'lea'},
      statuses: [_done],
    ).delete(by: lea, at: twoPm);

    final mine = MyStreets.of([nationale, deleted, paix], lea);

    expect(mine.all, [nationale, paix]);
    expect(mine.mine, [nationale]);
    expect(mine.teamProgress, _progress([_done, _toDo, _nobody, _done, _done]));
  });

  test('should give lists that cannot be modified', () {
    final mine = MyStreets.of(streets, lea);

    expect(() => mine.mine.add(paix), throwsUnsupportedError);
    expect(() => mine.others.add(paix), throwsUnsupportedError);
    expect(() => mine.all.add(paix), throwsUnsupportedError);
  });

  test('should have nothing when there is no street', () {
    final mine = MyStreets.of(const [], lea);

    expect(mine.all, isEmpty);
    expect(mine.teamProgress, Progress.empty);
  });

  test('should have no street and no door when none', () {
    expect(MyStreets.none.all, isEmpty);
    expect(MyStreets.none.mine, isEmpty);
    expect(MyStreets.none.others, isEmpty);
    expect(MyStreets.none.teamProgress, Progress.empty);
  });
}
