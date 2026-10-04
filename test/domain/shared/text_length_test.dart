import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';

void main() {
  test('should count each ASCII letter and space as one character', () {
    expect(characterCount('après 19h'), 9);
  });

  test('should count an emoji as one character when Dart counts two units', () {
    expect('🚒'.length, 2);
    expect(characterCount('🚒'), 1);
  });

  test('should count an accent typed as a separate mark as two characters', () {
    expect(characterCount('é'), 2);
  });

  test('should count nothing when the text is empty', () {
    expect(characterCount(''), 0);
  });
}
