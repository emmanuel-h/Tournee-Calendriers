import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/pending_sync/pending_sync_notifier.dart';
import 'package:tournee_calendriers/presentation/pending_sync/pending_sync_state.dart';

import '../../support/fakes/fake_pending_sync.dart';

/// The pending sync bound to the port, as the composition root does when
/// another tournée is opened: [open] replaces it.
final class _BoundPendingSync extends Notifier<FakePendingSync> {
  _BoundPendingSync(this._first);

  final FakePendingSync _first;

  @override
  FakePendingSync build() => _first;

  void open(FakePendingSync other) => state = other;
}

// « ☁ Modifications de 3 rues en attente d'envoi » (PLAN §5.3, §7).
void main() {
  late FakePendingSync pending;
  late NotifierProvider<_BoundPendingSync, FakePendingSync> bound;
  late ProviderContainer container;
  late List<PendingSyncState> seen;

  setUp(() async {
    pending = FakePendingSync();
    bound = NotifierProvider<_BoundPendingSync, FakePendingSync>(
      () => _BoundPendingSync(pending),
    );
    container = ProviderContainer(
      overrides: [pendingSyncProvider.overrideWith((ref) => ref.watch(bound))],
    );
    seen = [];
    // `listen` keeps the autoDispose notifier alive, as the start screen
    // watching it does, and records each state.
    container.listen(
      pendingSyncIndicatorProvider,
      (_, state) => seen.add(state),
      fireImmediately: true,
    );
    await pumpEventQueue();
  });

  tearDown(() => container.dispose());

  test('should say all is sent when no street waits', () {
    expect(container.read(pendingSyncIndicatorProvider), const AllSent());
  });

  test(
    'should follow the streets waiting from 0 to 2 to 1 and back to 0',
    () async {
      // One snapshot after the other, as Firestore sends them.
      for (final streets in [2, 1, 0]) {
        pending.unsent(streets);
        await pumpEventQueue();
      }

      expect(seen, const [
        AllSent(),
        ChangesWaiting(2),
        ChangesWaiting(1),
        AllSent(),
      ]);
    },
  );

  test('should show the changes waiting when the screen opens', () async {
    final again = ProviderContainer(
      overrides: [pendingSyncProvider.overrideWithValue(FakePendingSync(3))],
    );
    addTearDown(again.dispose);
    again.listen(pendingSyncIndicatorProvider, (_, _) {});

    // Nothing is said before the count arrives.
    expect(again.read(pendingSyncIndicatorProvider), const AllSent());
    await pumpEventQueue();

    expect(again.read(pendingSyncIndicatorProvider), const ChangesWaiting(3));
  });

  test('should show nothing when the count can no longer be read', () async {
    pending.unsent(2);
    await pumpEventQueue();
    expect(
      container.read(pendingSyncIndicatorProvider),
      const ChangesWaiting(2),
    );

    pending.fail(StateError('tournée gone'));
    await pumpEventQueue();

    expect(container.read(pendingSyncIndicatorProvider), const AllSent());
  });

  test(
    'should follow the tournée opened and stop following the one left',
    () async {
      pending.unsent(2);
      final other = FakePendingSync(1);

      container.read(bound.notifier).open(other);
      await pumpEventQueue();

      expect(
        container.read(pendingSyncIndicatorProvider),
        const ChangesWaiting(1),
      );
      expect(pending.isFollowed, isFalse);
      expect(other.isFollowed, isTrue);
    },
  );

  test('should stop following the count when nobody shows it', () async {
    container.dispose();

    expect(pending.isFollowed, isFalse);
  });
}
