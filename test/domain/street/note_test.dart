import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/note.dart';

import '../../support/results.dart';

void main() {
  group('create', () {
    test('should keep the text when it is short', () {
      final note = valueOf(Note.create('chien dans le jardin'));

      expect(note.text, 'chien dans le jardin');
    });

    test('should trim spaces and line breaks around the text', () {
      final note = valueOf(Note.create('  \n digicode 1234 \n '));

      expect(note.text, 'digicode 1234');
    });

    test('should keep line breaks inside the text', () {
      final note = valueOf(Note.create('portail vert\nsonner fort'));

      expect(note.text, 'portail vert\nsonner fort');
    });

    test('should give the empty note when the text is blank', () {
      final note = valueOf(Note.create(' \t\n '));

      expect(note.text, '');
      expect(note, Note.empty);
    });

    test('should accept the text when it has 199 characters', () {
      final note = valueOf(Note.create('a' * 199));

      expect(note.text, 'a' * 199);
    });

    test('should accept the text when it has exactly 200 characters', () {
      final note = valueOf(Note.create('a' * 200));

      expect(note.text, 'a' * 200);
    });

    test('should refuse the text when it has 201 characters', () {
      expect(failureOf(Note.create('a' * 201)), NoteFailure.tooLong);
    });

    test('should count the limit after trimming when spaces surround it', () {
      final note = valueOf(Note.create('   ${'a' * 200}   '));

      expect(note.text, 'a' * 200);
    });

    test('should accept 200 emoji when Dart counts them as 400 units', () {
      final text = '🚒' * 200;

      expect(valueOf(Note.create(text)).text, text);
    });

    test('should refuse 201 emoji', () {
      expect(failureOf(Note.create('🚒' * 201)), NoteFailure.tooLong);
    });
  });

  test('should allow 200 characters', () {
    expect(Note.maxLength, 200);
  });

  test('should hold no text when it is the empty note', () {
    expect(Note.empty.text, '');
  });

  group('equality', () {
    test('should be equal when the texts are equal', () {
      final a = valueOf(Note.create('chien'));
      final b = valueOf(Note.create(' chien '));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should differ when the texts differ', () {
      expect(
        valueOf(Note.create('chien')),
        isNot(valueOf(Note.create('chat'))),
      );
    });

    test('should differ from a value of another type with the same text', () {
      expect(valueOf(Note.create('chien')), isNot('chien'));
    });
  });

  test('should show its text when printed', () {
    expect(valueOf(Note.create('chien')).toString(), 'Note(chien)');
  });
}
