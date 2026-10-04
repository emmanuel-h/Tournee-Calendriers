import 'dart:math';

import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/system/random_id_generator.dart';
import 'package:tournee_calendriers/infrastructure/system/system_clock.dart';

void main() {
  group('SystemClock', () {
    test('should give the current time in UTC', () {
      final before = DateTime.now();

      final now = const SystemClock().now();

      expect(now.isUtc, isTrue);
      expect(now.isBefore(before), isFalse);
      expect(now.difference(before), lessThan(const Duration(seconds: 5)));
    });
  });

  group('RandomIdGenerator', () {
    test('should make 20 letters and digits', () {
      final id = RandomIdGenerator(Random(1)).newId();

      expect(id, hasLength(20));
      expect(id, matches(RegExp(r'^[A-Za-z0-9]{20}$')));
    });

    test('should make a different id each time', () {
      final ids = RandomIdGenerator(Random(1));

      expect(ids.newId(), isNot(ids.newId()));
    });

    test('should make the same ids from the same seed', () {
      expect(
        RandomIdGenerator(Random(7)).newId(),
        RandomIdGenerator(Random(7)).newId(),
      );
    });

    test('should use every letter and digit of its alphabet', () {
      final ids = RandomIdGenerator(Random(3));
      final seen = {for (var i = 0; i < 200; i++) ...ids.newId().split('')};

      expect(seen, hasLength(62));
    });

    test('should make ids by default without a seed', () {
      expect(RandomIdGenerator().newId(), hasLength(20));
    });
  });
}
