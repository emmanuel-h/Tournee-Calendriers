import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/street_part/street_part_notifier.dart';
import 'package:tournee_calendriers/presentation/street_part/street_part_state.dart';

import '../../support/geo_fixtures.dart';
import '../../support/street_fixtures.dart';

// The Rue Nationale of Villefranche-sur-Saône, as on the StreetPart mockup
// but shorter: 1, 3, 5, 7 north of a road running east, 2, 4, 6 south.
final _road = StreetShape([
  [at(45.98, 4.7195), at(45.98, 4.7210)],
]);

StreetPartChoice _choice({
  StreetPart part = StreetPart.whole,
  StreetShape? road,
}) => StreetPartChoice.start(
  numbers: [
    for (var k = 0; k < 4; k++)
      PartNumber(n('${2 * k + 1}'), position: at(45.98005, 4.72 + k * 1e-4)),
    for (var k = 0; k < 3; k++)
      PartNumber(n('${2 * k + 2}'), position: at(45.97995, 4.72 + k * 1e-4)),
  ],
  road: road ?? _road,
  part: part,
);

void main() {
  late ProviderContainer container;
  late StreetPartRequest request;

  void open(StreetPartChoice choice) {
    container = ProviderContainer();
    addTearDown(container.dispose);
    request = StreetPartRequest(streetName: 'Rue Nationale', choice: choice);
    // Keeps the auto-disposed provider alive, as the screen does.
    container.listen(streetPartProvider(request), (_, _) {});
  }

  StreetPartView view() => container.read(streetPartProvider(request));
  StreetPartNotifier notifier() =>
      container.read(streetPartProvider(request).notifier);

  test('should show the street, its numbers and the part it starts from', () {
    open(
      _choice(
        part: part(odd: range(3, 5), even: SidePart.all),
      ),
    );

    final shown = view();
    expect(shown.streetName, 'Rue Nationale');
    expect(shown.lowest, 1);
    expect(shown.highest, 7);
    expect(shown.side, Sides.both);
    expect(shown.part, part(odd: range(3, 5), even: SidePart.all));
    expect(shown.keptCount, 5);
    expect(shown.numberCount, 7);
    expect(shown.drawing!.dots, hasLength(7));
    expect(shown.bounds, (from: 3, to: 5));
    expect(notifier().chosen, part(odd: range(3, 5), even: SidePart.all));
  });

  test('should show one side with its own marks', () {
    open(
      _choice(
        part: part(odd: range(3, 5), even: SidePart.all),
      ),
    );

    notifier().chooseSide(Sides.odd);

    expect(view().side, Sides.odd);
    expect(view().drawing!.first!.place, const MarkBetween(1, 3));
    expect(view().drawing!.last!.place, const MarkBetween(5, 7));
  });

  test('should work the part out again when a mark moves', () {
    open(_choice());
    notifier().chooseSide(Sides.odd);

    notifier().moveMark(PartMark.first, 2);

    expect(view().part, part(odd: range(5, 7), even: SidePart.all));
    expect(view().keptCount, 5);
    expect(notifier().chosen, part(odd: range(5, 7), even: SidePart.all));
  });

  test('should hold the whole side shown', () {
    open(
      _choice(
        part: part(odd: range(3, 5), even: SidePart.none),
      ),
    );
    notifier().chooseSide(Sides.odd);

    notifier().holdAll();

    expect(view().part, part(odd: SidePart.all, even: SidePart.none));
  });

  test('should hold nothing of the side shown', () {
    open(_choice());
    notifier().chooseSide(Sides.even);

    notifier().holdNothing();

    expect(view().part, part(odd: SidePart.all, even: SidePart.none));
  });

  test('should keep the numbers between the bounds typed', () {
    open(_choice(road: StreetShape.none));
    notifier().chooseSide(Sides.odd);

    notifier().typeBounds(from: ' 3 ', to: '5');

    expect(view().part, part(odd: range(3, 5), even: SidePart.all));
    expect(view().bounds, (from: 3, to: 5));
  });

  test('should take a blank or unreadable bound as the end of the side', () {
    open(_choice());
    notifier().chooseSide(Sides.odd);

    notifier().typeBounds(from: '', to: '5');
    expect(view().part, part(odd: range(1, 5), even: SidePart.all));

    notifier().typeBounds(from: '3', to: '99999999999999999999999');
    expect(view().part, part(odd: range(3, 7), even: SidePart.all));
  });
}
