import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/move_streets/move_streets_notifier.dart';
import 'package:tournee_calendriers/presentation/move_streets/move_streets_state.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart' as fixtures;
import '../../support/fakes/fake_moved_streets_log.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

// The card « 12 rues sont enregistrées sur ce téléphone. » of the start
// screen (PLAN §5.0).
void main() {
  final leaUid = fixtures.leaId;

  /// The 12, where Léa is active too.
  final team12 = valueOf(
    Tournee.create(
      id: tournee12.id,
      number: tournee12.number,
      centre: fixtures.csVillefranche,
      joinCode: fixtures.codeOf('K7P-3QX'),
      createdBy: fixtures.manuId,
      createdAt: fixtures.createdAt,
      currentCampaign: fixtures.campaign2026,
      members: [fixtures.manu, fixtures.lea],
    ),
  );

  Street phoneStreet(String id, String name, String banId) => valueOf(
    Street.create(
      id: StreetId(id),
      name: name,
      commune: villefranche,
      banId: BanStreetId(banId),
    ),
  );

  final nationale = phoneStreet('s1', 'Rue Nationale', '69264_0420');
  final morin = phoneStreet('s2', 'Rue Pierre Morin', '69264_1460');

  late FakeStreetRepository phone;
  late FakeStreetRepository tourneeStreets;
  late FakeMovedStreetsLog log;
  late FakeTourneeRepository tournees;
  late FakeMyTourneesStore store;

  setUp(() {
    phone = FakeStreetRepository([nationale, morin]);
    tourneeStreets = FakeStreetRepository();
    log = FakeMovedStreetsLog();
    tournees = FakeTourneeRepository([fixtures.team(), team12]);
    store = FakeMyTourneesStore(
      valueOf(
        MyTournees.none
            .remember(tournee49)
            .remember(tournee12)
            .open(tournee49.id),
      ),
    );
  });

  /// Léa's phone (or [member]'s), the card followed as the start screen
  /// does.
  ProviderContainer phoneOf({MemberId? member}) {
    final container = ProviderContainer(
      overrides: [
        phoneStreetRepositoryProvider.overrideWithValue(phone),
        streetRepositoryProvider.overrideWithValue(tourneeStreets),
        movedStreetsLogProvider.overrideWithValue(log),
        tourneeRepositoryProvider.overrideWithValue(tournees),
        myTourneesStoreProvider.overrideWithValue(store),
        identityProvider.overrideWithValue(FakeIdentity(member ?? leaUid)),
      ],
    );
    addTearDown(container.dispose);
    // `autoDispose`: a listener keeps the notifier alive, as the screen.
    container.listen(moveStreetsProvider, (_, _) {});
    return container;
  }

  /// The card once the phone's streets are counted.
  Future<MoveStreetsState> cardOf(ProviderContainer container) async {
    await pumpEventQueue();
    return container.read(moveStreetsProvider);
  }

  Future<void> open(TourneeId? id) => store.save(
    id == null
        ? store.myTournees.forget(tournee49.id).remember(tournee49)
        : valueOf(store.myTournees.open(id)),
  );

  group('the card', () {
    test('should offer the phone streets to the open tournée', () async {
      expect(await cardOf(phoneOf()), const StreetsToMove(2));
    });

    test('should not show before the streets are counted', () {
      expect(phoneOf().read(moveStreetsProvider), const NoStreetsToMove());
    });

    test('should not show when no tournée is open', () async {
      store = FakeMyTourneesStore(MyTournees.none.remember(tournee49));

      expect(await cardOf(phoneOf()), const NoStreetsToMove());
    });

    test('should not show once the streets went into the tournée', () async {
      log = FakeMovedStreetsLog([tournee49.id]);

      expect(await cardOf(phoneOf()), const NoStreetsToMove());
    });

    test('should not show to a member the tournée does not know', () async {
      expect(
        await cardOf(phoneOf(member: MemberId('phone42'))),
        const NoStreetsToMove(),
      );
    });

    test('should not show when the tournée cannot be read', () async {
      tournees.findError = StateError('unreadable');

      expect(await cardOf(phoneOf()), const NoStreetsToMove());
    });

    test('should follow the tournée opened', () async {
      log = FakeMovedStreetsLog([tournee49.id]);
      final container = phoneOf();
      expect(await cardOf(container), const NoStreetsToMove());

      await open(tournee12.id);

      expect(await cardOf(container), const StreetsToMove(2));
    });

    test('should not show the count of a tournée no longer open', () async {
      final container = phoneOf();

      // Closed before its streets were counted; the card is built again
      // at once, before the old count ends.
      await open(null);
      expect(container.read(moveStreetsProvider), const NoStreetsToMove());

      expect(await cardOf(container), const NoStreetsToMove());
    });
  });

  group('move', () {
    test('should add the streets to the tournée and say how many', () async {
      final container = phoneOf();
      await cardOf(container);

      final summary = await container.read(moveStreetsProvider.notifier).move();

      expect(summary, const MovedSummary(moved: 2, alreadyThere: 0));
      expect(
        [for (final street in tourneeStreets.added) street.id],
        [StreetId('s1'), StreetId('s2')],
      );
      expect(log.remembered, [tournee49.id]);
    });

    test('should count the streets the tournée already had', () async {
      tourneeStreets = FakeStreetRepository([
        phoneStreet('t-1', 'Rue Nationale', '69264_0420'),
      ]);
      final container = phoneOf();
      await cardOf(container);

      final summary = await container.read(moveStreetsProvider.notifier).move();

      expect(summary, const MovedSummary(moved: 1, alreadyThere: 1));
    });

    test('should show how far it went, then hide the card', () async {
      final container = phoneOf();
      await cardOf(container);
      final states = <MoveStreetsState>[];
      container.listen(moveStreetsProvider, (_, next) => states.add(next));

      await container.read(moveStreetsProvider.notifier).move();

      expect(states, const [
        MovingStreets(done: 0, total: 2),
        MovingStreets(done: 1, total: 2),
        MovingStreets(done: 2, total: 2),
        NoStreetsToMove(),
      ]);
    });

    test('should not offer them again to that tournée', () async {
      final container = phoneOf();
      await cardOf(container);
      await container.read(moveStreetsProvider.notifier).move();

      await open(tournee12.id);
      await open(tournee49.id);

      expect(await cardOf(container), const NoStreetsToMove());
    });

    test('should do nothing while the card is not shown', () async {
      log = FakeMovedStreetsLog([tournee49.id]);
      final container = phoneOf();
      await cardOf(container);

      final summary = await container.read(moveStreetsProvider.notifier).move();

      expect(summary, isNull);
      expect(tourneeStreets.added, isEmpty);
    });

    test(
      'should finish in the tournée it started in when another is opened',
      () async {
        final container = phoneOf();
        await cardOf(container);
        tourneeStreets.holdAdds = Completer<void>();

        final moving = container.read(moveStreetsProvider.notifier).move();
        await pumpEventQueue();
        await open(tournee12.id);
        // The 12's card, built at once: the 49's move must not show on it.
        expect(container.read(moveStreetsProvider), const NoStreetsToMove());
        final shownFor12 = <MoveStreetsState>[];
        container.listen(
          moveStreetsProvider,
          (_, next) => shownFor12.add(next),
        );
        tourneeStreets.holdAdds!.complete();
        final summary = await moving;
        await pumpEventQueue();

        expect(summary, const MovedSummary(moved: 2, alreadyThere: 0));
        expect(log.remembered, [tournee49.id]);
        // The 12 shows its own card, not the end of the 49's move.
        expect(shownFor12, const [StreetsToMove(2)]);
      },
    );
  });

  group('later', () {
    test('should hide the card', () async {
      final container = phoneOf();
      await cardOf(container);

      container.read(moveStreetsProvider.notifier).later();

      expect(await cardOf(container), const NoStreetsToMove());
      expect(tourneeStreets.added, isEmpty);
      expect(log.remembered, isEmpty);
    });

    test(
      'should keep it hidden for that tournée until the next launch',
      () async {
        final container = phoneOf();
        await cardOf(container);
        container.read(moveStreetsProvider.notifier).later();

        await open(tournee12.id);
        expect(await cardOf(container), const StreetsToMove(2));
        await open(tournee49.id);
        expect(await cardOf(container), const NoStreetsToMove());

        // The next launch: a new container.
        expect(await cardOf(phoneOf()), const StreetsToMove(2));
      },
    );

    test('should do nothing when no tournée is open', () async {
      store = FakeMyTourneesStore(MyTournees.none.remember(tournee49));
      final container = phoneOf();
      await cardOf(container);

      container.read(moveStreetsProvider.notifier).later();

      expect(container.read(postponedMovesProvider), isEmpty);
    });
  });

  group('states', () {
    test('should be equal when their values are equal', () {
      expect(const StreetsToMove(2), const StreetsToMove(2));
      expect(const StreetsToMove(2).hashCode, const StreetsToMove(2).hashCode);
      expect(const StreetsToMove(2), isNot(const StreetsToMove(3)));
      expect(const StreetsToMove(2).count, 2);
      expect(
        const MovingStreets(done: 1, total: 2),
        const MovingStreets(done: 1, total: 2),
      );
      expect(
        const MovingStreets(done: 1, total: 2).hashCode,
        const MovingStreets(done: 1, total: 2).hashCode,
      );
      expect(
        const MovingStreets(done: 1, total: 2),
        isNot(const MovingStreets(done: 2, total: 2)),
      );
      expect(
        const MovingStreets(done: 1, total: 2),
        isNot(const MovingStreets(done: 1, total: 3)),
      );
      expect(const NoStreetsToMove(), const NoStreetsToMove());
      expect(
        const NoStreetsToMove().hashCode,
        const NoStreetsToMove().hashCode,
      );
      expect(const NoStreetsToMove(), isNot(const StreetsToMove(0)));
    });

    test('should compare summaries by their counts', () {
      const summary = MovedSummary(moved: 10, alreadyThere: 2);

      expect(summary.moved, 10);
      expect(summary.alreadyThere, 2);
      expect(summary, const MovedSummary(moved: 10, alreadyThere: 2));
      expect(
        summary.hashCode,
        const MovedSummary(moved: 10, alreadyThere: 2).hashCode,
      );
      expect(summary, isNot(const MovedSummary(moved: 9, alreadyThere: 2)));
      expect(summary, isNot(const MovedSummary(moved: 10, alreadyThere: 1)));
    });
  });
}
