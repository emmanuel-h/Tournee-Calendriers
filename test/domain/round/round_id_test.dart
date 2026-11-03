import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';

void main() {
  test('should keep its value and equal an id of the same value', () {
    final id = RoundId('round-1');

    expect(id.value, 'round-1');
    expect(id, RoundId('round-1'));
    expect(id.hashCode, RoundId('round-1').hashCode);
    expect(id, isNot(RoundId('round-2')));
    expect(id.toString(), 'RoundId(round-1)');
  });

  test('should refuse a blank id', () {
    expect(() => RoundId(' '), throwsArgumentError);
  });
}
