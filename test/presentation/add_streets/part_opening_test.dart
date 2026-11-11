import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/add_streets/part_opening.dart';
import 'package:tournee_calendriers/presentation/street_part/street_part_state.dart';

import '../../support/street_fixtures.dart';

void main() {
  test('should hold the request « Partie de la rue » opens on', () {
    final request = StreetPartRequest(
      streetName: 'Rue Pierre Morin',
      choice: StreetPartChoice.start(
        numbers: [PartNumber(n('1'))],
        road: StreetShape.none,
        part: StreetPart.whole,
      ),
    );

    expect(PartToChoose(request).request, same(request));
  });

  test('should tell the unreadable parts apart by their problem', () {
    const offline = PartUnreadable(PartReadProblem.noNetwork);

    expect(offline, const PartUnreadable(PartReadProblem.noNetwork));
    expect(
      offline.hashCode,
      const PartUnreadable(PartReadProblem.noNetwork).hashCode,
    );
    expect(offline, isNot(const PartUnreadable(PartReadProblem.unavailable)));
    expect(offline.toString(), 'PartUnreadable(noNetwork)');
  });

  test('should hold the problem it is made with', () {
    // Not `const`: built while the test runs, as coverage counts it.
    // ignore: prefer_const_constructors
    final unavailable = PartUnreadable(PartReadProblem.unavailable);

    expect(unavailable.problem, PartReadProblem.unavailable);
  });

  test('should tell the streets added meanwhile apart by their name', () {
    const lilas = PartOfStreetInSector('Rue des Lilas');

    expect(lilas, const PartOfStreetInSector('Rue des Lilas'));
    expect(
      lilas.hashCode,
      const PartOfStreetInSector('Rue des Lilas').hashCode,
    );
    expect(lilas, isNot(const PartOfStreetInSector('Rue Pasteur')));
    expect(lilas.toString(), 'PartOfStreetInSector(Rue des Lilas)');
  });

  test('should make every part not opened equal', () {
    // ignore: prefer_const_constructors
    expect(PartNotOpened(), const PartNotOpened());
    expect(const PartNotOpened().hashCode, const PartNotOpened().hashCode);
    expect(const PartNotOpened(), isNot(const PartOfStreetInSector('Rue')));
    expect(const PartNotOpened().toString(), 'PartNotOpened');
  });
}
