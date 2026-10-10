import 'package:test/test.dart';
import 'package:tournee_calendriers/presentation/pending_sync/pending_sync_state.dart';

void main() {
  test('should equal another « all sent »', () {
    expect(const AllSent(), const AllSent());
    expect(const AllSent().hashCode, const AllSent().hashCode);
  });

  test('should equal the changes of as many streets', () {
    expect(const ChangesWaiting(2), const ChangesWaiting(2));
    expect(const ChangesWaiting(2).hashCode, const ChangesWaiting(2).hashCode);
  });

  test('should differ when the number of streets differs', () {
    expect(const ChangesWaiting(2), isNot(const ChangesWaiting(1)));
    expect(const ChangesWaiting(1), isNot(const AllSent()));
    expect(const AllSent(), isNot(const ChangesWaiting(1)));
  });
}
