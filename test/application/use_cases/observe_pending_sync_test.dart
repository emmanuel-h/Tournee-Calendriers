import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/observe_pending_sync.dart';

import '../../support/fakes/fake_pending_sync.dart';

void main() {
  test(
    'should give the streets waiting to be sent, then each new count',
    () async {
      final pending = FakePendingSync(3);
      final counts = <int>[];

      final listening = ObservePendingSync(pending)().listen(counts.add);
      addTearDown(listening.cancel);
      await pumpEventQueue();
      pending
        ..unsent(1)
        ..unsent(0);
      await pumpEventQueue();

      expect(counts, [3, 1, 0]);
    },
  );
}
