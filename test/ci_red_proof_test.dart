import 'package:test/test.dart';

// Deliberately failing: proves CI turns red (T0.3). Never merged.
void main() {
  test('should fail on purpose to prove CI goes red', () {
    expect(1 + 1, 3);
  });
}
