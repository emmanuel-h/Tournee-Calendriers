import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/round/rounds_unreadable_notice.dart';
import 'package:tournee_calendriers/presentation/round/unsent_rounds_sender.dart';

import '../../domain/round/round_fixtures.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_round_ledger.dart';

void main() {
  late FakeOpenRoundStore rounds;
  late FakeRoundLedger ledger;
  late ProviderContainer container;

  final first = newRound().validate(endedAt);

  setUp(() {
    rounds = FakeOpenRoundStore(null, [first]);
    ledger = FakeRoundLedger();
    container = ProviderContainer(
      overrides: [
        openRoundStoreProvider.overrideWithValue(rounds),
        roundLedgerProvider.overrideWithValue(ledger),
      ],
    );
    addTearDown(container.dispose);
  });

  group('unsentRoundsSenderProvider', () {
    test('should send what waits once kept alive, then each new one', () async {
      container.listen(unsentRoundsSenderProvider, (_, _) {});
      await pumpEventQueue();
      final next = newRound().validate(endedAt.add(const Duration(days: 1)));

      await rounds.keepValidated(next);
      await pumpEventQueue();

      expect(ledger.asked, [first.summary, next.summary]);
      expect(rounds.unsent, isEmpty);
    });

    test('should send nothing more once disposed', () async {
      container.listen(unsentRoundsSenderProvider, (_, _) {});
      await pumpEventQueue();
      container.dispose();

      await rounds.keepValidated(first);
      await pumpEventQueue();

      expect(ledger.asked, [first.summary]);
      expect(rounds.unsent, [first]);
    });
  });

  group('roundsUnreadableNoticeProvider', () {
    test('should owe nothing when the tournées were read', () {
      expect(container.read(roundsUnreadableNoticeProvider), isFalse);
    });

    test('should owe the message once when they were not', () {
      rounds.unreadableAtStart = true;

      expect(container.read(roundsUnreadableNoticeProvider), isTrue);

      container.read(roundsUnreadableNoticeProvider.notifier).told();

      expect(container.read(roundsUnreadableNoticeProvider), isFalse);
    });
  });
}
