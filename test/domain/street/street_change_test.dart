import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/street_fixtures.dart';

void main() {
  final lilas = StreetId('rue-des-lilas');
  final gambetta = StreetId('rue-gambetta');
  final twelve = House(number: n('12'), comeBack: comeBack('après 19h'));
  final twelveDone = House(number: n('12'), status: VisitStatus.done);

  group('HouseMarked', () {
    HouseMarked marked({
      StreetId? streetId,
      House? before,
      VisitStatus status = VisitStatus.nobodyHome,
      ChangeStamp? stamp,
    }) => HouseMarked(
      streetId: streetId ?? lilas,
      before: before ?? twelve,
      status: status,
      stamp: stamp ?? leaAtTwo,
    );

    test('should name the house it changed after the house before', () {
      final change = marked();

      expect(change.streetId, lilas);
      expect(change.number, n('12'));
      expect(change.before, twelve);
      expect(change.status, VisitStatus.nobodyHome);
      expect(change.stamp, leaAtTwo);
    });

    test('should clear the come-back when the house becomes done', () {
      expect(marked(status: VisitStatus.done).clearsComeBack, isTrue);
    });

    test('should keep the come-back when nobody was home', () {
      expect(marked(status: VisitStatus.nobodyHome).clearsComeBack, isFalse);
    });

    test('should keep the come-back when the house goes back to do', () {
      expect(marked(status: VisitStatus.toDo).clearsComeBack, isFalse);
    });

    test('should be equal when every field is equal', () {
      expect(marked(), marked());
      expect(marked().hashCode, marked().hashCode);
    });

    test('should differ when the streets differ', () {
      expect(marked(), isNot(marked(streetId: gambetta)));
    });

    test('should differ when the houses before differ', () {
      expect(marked(), isNot(marked(before: twelveDone)));
    });

    test('should differ when the statuses differ', () {
      expect(marked(), isNot(marked(status: VisitStatus.toDo)));
    });

    test('should differ when the stamps differ', () {
      expect(marked(), isNot(marked(stamp: paulAtThree)));
    });

    test('should differ from another change of the same house', () {
      final noteSet = NoteSet(
        streetId: lilas,
        before: twelve,
        note: Note.empty,
        stamp: leaAtTwo,
      );

      expect(marked(), isNot(noteSet));
    });

    test('should show its fields when printed', () {
      expect(
        marked().toString(),
        'HouseMarked(rue-des-lilas, 12, VisitStatus.nobodyHome, '
        'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
      );
    });
  });

  group('ComeBackSet', () {
    ComeBackSet set({
      StreetId? streetId,
      House? before,
      ComeBack? comeBack = ComeBack.withoutHint,
      ChangeStamp? stamp,
    }) => ComeBackSet(
      streetId: streetId ?? lilas,
      before: before ?? twelve,
      comeBack: comeBack,
      stamp: stamp ?? leaAtTwo,
    );

    test('should carry the new come-back and the house before', () {
      final change = set(comeBack: comeBack('le samedi'));

      expect(change.streetId, lilas);
      expect(change.number, n('12'));
      expect(change.before, twelve);
      expect(change.comeBack, comeBack('le samedi'));
      expect(change.stamp, leaAtTwo);
    });

    test('should be equal when every field is equal', () {
      expect(set(), set());
      expect(set().hashCode, set().hashCode);
    });

    test('should differ when the streets differ', () {
      expect(set(), isNot(set(streetId: gambetta)));
    });

    test('should differ when the houses before differ', () {
      expect(set(), isNot(set(before: twelveDone)));
    });

    test('should differ when the come-backs differ', () {
      expect(set(), isNot(set(comeBack: null)));
    });

    test('should differ when the stamps differ', () {
      expect(set(), isNot(set(stamp: paulAtThree)));
    });

    test('should show its fields when printed', () {
      expect(
        set().toString(),
        'ComeBackSet(rue-des-lilas, 12, ComeBack(), '
        'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
      );
    });
  });

  group('NoteSet', () {
    NoteSet set({
      StreetId? streetId,
      House? before,
      Note? newNote,
      ChangeStamp? stamp,
    }) => NoteSet(
      streetId: streetId ?? lilas,
      before: before ?? twelve,
      note: newNote ?? note('chien'),
      stamp: stamp ?? leaAtTwo,
    );

    test('should carry the new note and the house before', () {
      final change = set();

      expect(change.streetId, lilas);
      expect(change.number, n('12'));
      expect(change.before, twelve);
      expect(change.note, note('chien'));
      expect(change.stamp, leaAtTwo);
    });

    test('should be equal when every field is equal', () {
      expect(set(), set());
      expect(set().hashCode, set().hashCode);
    });

    test('should differ when the streets differ', () {
      expect(set(), isNot(set(streetId: gambetta)));
    });

    test('should differ when the houses before differ', () {
      expect(set(), isNot(set(before: twelveDone)));
    });

    test('should differ when the notes differ', () {
      expect(set(), isNot(set(newNote: Note.empty)));
    });

    test('should differ when the stamps differ', () {
      expect(set(), isNot(set(stamp: paulAtThree)));
    });

    test('should show its fields when printed', () {
      expect(
        set().toString(),
        'NoteSet(rue-des-lilas, 12, Note(chien), '
        'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
      );
    });
  });

  group('StreetDeleted', () {
    test('should carry who deleted the street and when', () {
      final change = StreetDeleted(streetId: lilas, deletion: paulAtThree);

      expect(change.streetId, lilas);
      expect(change.deletion, paulAtThree);
    });

    test('should be equal when every field is equal', () {
      final a = StreetDeleted(streetId: lilas, deletion: paulAtThree);
      final b = StreetDeleted(streetId: lilas, deletion: paulAtThree);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should differ when the streets differ', () {
      expect(
        StreetDeleted(streetId: lilas, deletion: paulAtThree),
        isNot(StreetDeleted(streetId: gambetta, deletion: paulAtThree)),
      );
    });

    test('should differ when the deletions differ', () {
      expect(
        StreetDeleted(streetId: lilas, deletion: paulAtThree),
        isNot(StreetDeleted(streetId: lilas, deletion: leaAtTwo)),
      );
    });

    test('should differ from a restoration of the same street', () {
      expect(
        StreetDeleted(streetId: lilas, deletion: paulAtThree),
        isNot(StreetRestored(streetId: lilas)),
      );
    });

    test('should show its fields when printed', () {
      expect(
        StreetDeleted(streetId: lilas, deletion: paulAtThree).toString(),
        'StreetDeleted(rue-des-lilas, '
        'ChangeStamp(paul, 2026-11-02 15:00:00.000Z))',
      );
    });
  });

  group('StreetRestored', () {
    test('should name the restored street', () {
      expect(StreetRestored(streetId: lilas).streetId, lilas);
    });

    test('should be equal when the streets are equal', () {
      expect(StreetRestored(streetId: lilas), StreetRestored(streetId: lilas));
      expect(
        StreetRestored(streetId: lilas).hashCode,
        StreetRestored(streetId: lilas).hashCode,
      );
    });

    test('should differ when the streets differ', () {
      expect(
        StreetRestored(streetId: lilas),
        isNot(StreetRestored(streetId: gambetta)),
      );
    });

    test('should show its street when printed', () {
      expect(
        StreetRestored(streetId: lilas).toString(),
        'StreetRestored(rue-des-lilas)',
      );
    });
  });
}
