import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/observe_offline.dart';

import '../../support/fakes/fake_server_connection.dart';

void main() {
  test('should tell whether the phone is offline, then each change', () async {
    final connection = FakeServerConnection(offline: true);
    final seen = <bool>[];

    final listening = ObserveOffline(connection)().listen(seen.add);
    addTearDown(listening.cancel);
    await pumpEventQueue();
    connection
      ..reach(offline: false)
      ..reach(offline: true);
    await pumpEventQueue();

    expect(seen, [true, false, true]);
  });
}
