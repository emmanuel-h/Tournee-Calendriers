import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

void main() {
  test('should be true when both lists hold equal items in the same order', () {
    expect(sameItems(['a', 'b'], ['a', 'b']), isTrue);
  });

  test('should be true when both lists are empty', () {
    expect(sameItems(<String>[], <String>[]), isTrue);
  });

  test('should be false when the lengths differ', () {
    expect(sameItems(['a'], ['a', 'b']), isFalse);
  });

  test('should be false when one item differs', () {
    expect(sameItems(['a', 'b'], ['a', 'c']), isFalse);
  });

  test('should be false when the order differs', () {
    expect(sameItems(['a', 'b'], ['b', 'a']), isFalse);
  });
}
