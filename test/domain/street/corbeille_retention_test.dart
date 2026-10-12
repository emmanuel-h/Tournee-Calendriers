import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/corbeille_retention.dart';

import '../../support/street_fixtures.dart';

final removedAt = DateTime.utc(2026, 10, 1, 9, 30);
final removal = ChangeStamp(by: paul, at: removedAt);

void main() {
  test('should keep items 30 days', () {
    expect(corbeilleRetention, const Duration(days: 30));
  });

  test('should keep an item removed 29 days ago', () {
    final now = removedAt.add(const Duration(days: 29));

    expect(isPastRetention(removal, now: now), isFalse);
  });

  test('should keep an item removed exactly 30 days ago', () {
    final now = removedAt.add(const Duration(days: 30));

    expect(isPastRetention(removal, now: now), isFalse);
  });

  test('should purge an item removed 30 days and one second ago', () {
    final now = removedAt.add(const Duration(days: 30, seconds: 1));

    expect(isPastRetention(removal, now: now), isTrue);
  });

  test('should purge an item removed 31 days ago', () {
    final now = removedAt.add(const Duration(days: 31));

    expect(isPastRetention(removal, now: now), isTrue);
  });

  test('should keep an item stamped later than now by a phone whose clock '
      'is ahead', () {
    final now = removedAt.subtract(const Duration(days: 40));

    expect(isPastRetention(removal, now: now), isFalse);
  });
}
