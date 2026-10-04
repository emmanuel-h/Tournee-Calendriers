import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/street_fixtures.dart';

void main() {
  test('should be to do, without come-back, note or change when new', () {
    final house = House(number: n('12'));

    expect(house.number, n('12'));
    expect(house.status, VisitStatus.toDo);
    expect(house.comeBack, isNull);
    expect(house.note, Note.empty);
    expect(house.lastChange, isNull);
  });

  test('should keep every field when given them', () {
    final house = House(
      number: n('3bis'),
      status: VisitStatus.nobodyHome,
      comeBack: comeBack('après 19h'),
      note: note('chien dans le jardin'),
      lastChange: leaAtTwo,
    );

    expect(house.number, n('3bis'));
    expect(house.status, VisitStatus.nobodyHome);
    expect(house.comeBack, comeBack('après 19h'));
    expect(house.note, note('chien dans le jardin'));
    expect(house.lastChange, leaAtTwo);
  });

  test('should keep the come-back when the house is to do', () {
    final house = House(number: n('5'), comeBack: ComeBack.withoutHint);

    expect(house.comeBack, ComeBack.withoutHint);
  });

  test('should drop the come-back when the house is done', () {
    final house = House(
      number: n('5'),
      status: VisitStatus.done,
      comeBack: comeBack('après 19h'),
    );

    expect(house.comeBack, isNull);
  });

  group('progress', () {
    test('should count one done door when the house is done', () {
      final house = House(number: n('2'), status: VisitStatus.done);

      expect(house.progress, Progress.of(VisitStatus.done, comeBack: false));
    });

    test('should count the come-back when the house has one', () {
      final house = House(
        number: n('7'),
        status: VisitStatus.nobodyHome,
        comeBack: ComeBack.withoutHint,
      );

      expect(
        house.progress,
        Progress.of(VisitStatus.nobodyHome, comeBack: true),
      );
    });

    test('should count no come-back when the house has none', () {
      final house = House(number: n('7'));

      expect(house.progress, Progress.of(VisitStatus.toDo, comeBack: false));
    });
  });

  group('equality', () {
    House full() => House(
      number: n('3bis'),
      status: VisitStatus.nobodyHome,
      comeBack: comeBack('après 19h'),
      note: note('chien'),
      lastChange: leaAtTwo,
    );

    test('should be equal when every field is equal', () {
      expect(full(), full());
      expect(full().hashCode, full().hashCode);
    });

    final others = <String, House>{
      'number': House(
        number: n('3ter'),
        status: VisitStatus.nobodyHome,
        comeBack: comeBack('après 19h'),
        note: note('chien'),
        lastChange: leaAtTwo,
      ),
      'status': House(
        number: n('3bis'),
        comeBack: comeBack('après 19h'),
        note: note('chien'),
        lastChange: leaAtTwo,
      ),
      'come-back': House(
        number: n('3bis'),
        status: VisitStatus.nobodyHome,
        note: note('chien'),
        lastChange: leaAtTwo,
      ),
      'note': House(
        number: n('3bis'),
        status: VisitStatus.nobodyHome,
        comeBack: comeBack('après 19h'),
        lastChange: leaAtTwo,
      ),
      'last change': House(
        number: n('3bis'),
        status: VisitStatus.nobodyHome,
        comeBack: comeBack('après 19h'),
        note: note('chien'),
        lastChange: paulAtThree,
      ),
    };
    others.forEach((field, other) {
      test('should differ when the ${field}s differ', () {
        expect(full(), isNot(other));
      });
    });

    test('should differ from a value of another type', () {
      expect(House(number: n('3')), isNot(n('3')));
    });
  });

  test('should show its fields when printed', () {
    final house = House(
      number: n('12'),
      status: VisitStatus.nobodyHome,
      comeBack: comeBack('après 19h'),
      note: note('chien'),
      lastChange: leaAtTwo,
    );

    expect(
      house.toString(),
      'House(12, VisitStatus.nobodyHome, ComeBack(après 19h), Note(chien), '
      'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
    );
  });
}
