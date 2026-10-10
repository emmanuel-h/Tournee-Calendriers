import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_state.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/results.dart';

/// The 49, the 12 and the pending 7; [open] is the one the app shows.
MyTournees _manusPhone({TourneeId? open}) {
  final mine = MyTournees.none
      .remember(tournee49)
      .remember(tournee12)
      .remember(tournee7);
  return open == null ? mine : valueOf(mine.open(open));
}

void main() {
  late FakeMyTourneesStore store;
  late FakeTourneeDirectory directory;

  ProviderContainer containerWith(MyTournees mine) {
    store = FakeMyTourneesStore(mine);
    directory = FakeTourneeDirectory();
    final container = ProviderContainer(
      overrides: [
        myTourneesStoreProvider.overrideWithValue(store),
        tourneeDirectoryProvider.overrideWithValue(directory),
        memberAccountProvider.overrideWithValue(
          FakeMemberAccount(signedInMember: manuId),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('should reopen the tournée the phone kept open at launch', () {
    final container = containerWith(_manusPhone(open: tournee12.id));

    final state = container.read(myTourneesProvider);

    expect(state.current, tournee12);
    expect(container.read(currentTourneeProvider), tournee12);
  });

  test('should list the tournées in the phone order, each with its '
      'number, year, centre and status', () {
    final container = containerWith(_manusPhone(open: tournee12.id));

    final rows = container.read(myTourneesProvider).rows;

    expect(rows.map((row) => row.id), [
      tournee49.id,
      tournee12.id,
      tournee7.id,
    ]);
    expect(rows.map((row) => row.status), [
      TourneeRowStatus.closed,
      TourneeRowStatus.open,
      TourneeRowStatus.pending,
    ]);
    expect(rows.first.number, 49);
    expect(rows.first.campaign, 2026);
    expect(rows.first.centre, 'CS Villefranche');
  });

  test('should show no tournée when the phone knows none', () {
    final container = containerWith(MyTournees.none);

    final state = container.read(myTourneesProvider);

    expect(state.rows, isEmpty);
    expect(state.current, isNull);
    expect(container.read(currentTourneeProvider), isNull);
  });

  test('should switch the observed tournée and keep it for the next '
      'launch', () async {
    final container = containerWith(_manusPhone(open: tournee49.id));
    final observed = <Object?>[];
    container.listen(
      currentTourneeProvider,
      (_, current) => observed.add(current),
    );

    await container.read(myTourneesProvider.notifier).open(tournee12.id);

    expect(container.read(myTourneesProvider).current, tournee12);
    // Riverpod tells the listeners of a derived provider once it is read
    // again (or at the next frame).
    expect(container.read(currentTourneeProvider), tournee12);
    expect(observed, [tournee12]);
    expect(store.saves.single.currentId, tournee12.id);
  });

  test('should keep the open tournée when the one asked cannot be '
      'opened', () async {
    final container = containerWith(_manusPhone(open: tournee49.id));

    await container.read(myTourneesProvider.notifier).open(tournee7.id);

    expect(container.read(myTourneesProvider).current, tournee49);
    expect(store.saves, isEmpty);
  });

  test('should follow a list changed elsewhere', () async {
    final container = containerWith(_manusPhone(open: tournee49.id));
    container.read(myTourneesProvider);

    await store.save(valueOf(_manusPhone().open(tournee12.id)));

    expect(container.read(myTourneesProvider).current, tournee12);
  });

  group('pending requests', () {
    test('should watch each pending request as the signed-in member', () {
      final container = containerWith(_manusPhone(open: tournee49.id));

      container.read(myTourneesProvider);

      expect(directory.watched, [(tournee7.id, manuId)]);
    });

    test('should make an accepted request one of the tournées, not '
        'opened, and stop watching it', () async {
      final container = containerWith(_manusPhone(open: tournee49.id));
      container.read(myTourneesProvider);

      directory.answer(tournee7.id, MemberStatus.active);
      await pumpEventQueue();

      final rows = container.read(myTourneesProvider).rows;
      expect(rows.last.id, tournee7.id);
      expect(rows.last.status, TourneeRowStatus.closed);
      expect(container.read(myTourneesProvider).current, tournee49);
      expect(directory.isWatching(tournee7.id), isFalse);
    });

    test('should drop a refused request', () async {
      final container = containerWith(_manusPhone(open: tournee49.id));
      container.read(myTourneesProvider);

      directory.answer(tournee7.id, null);
      await pumpEventQueue();

      expect(container.read(myTourneesProvider).rows.map((row) => row.id), [
        tournee49.id,
        tournee12.id,
      ]);
    });

    test('should keep the request pending when its listener fails', () async {
      final container = containerWith(_manusPhone(open: tournee49.id));
      container.read(myTourneesProvider);

      directory.fail(tournee7.id);
      await pumpEventQueue();

      expect(
        container.read(myTourneesProvider).rows.last.status,
        TourneeRowStatus.pending,
      );
      expect(store.saves, isEmpty);
    });

    test('should watch a request the phone sends later', () async {
      final container = containerWith(MyTournees.none);
      container.read(myTourneesProvider);

      await store.save(MyTournees.none.remember(tournee7));

      expect(directory.watched, [(tournee7.id, manuId)]);
      expect(directory.isWatching(tournee7.id), isTrue);
    });

    test(
      'should watch a request once however often the list changes',
      () async {
        final container = containerWith(_manusPhone(open: tournee49.id));
        container.read(myTourneesProvider);

        await store.save(valueOf(_manusPhone().open(tournee12.id)));

        expect(directory.watched, hasLength(1));
      },
    );

    test('should stop watching when the app goes away', () {
      final container = containerWith(_manusPhone(open: tournee49.id));
      container.read(myTourneesProvider);

      container.dispose();

      expect(directory.isWatching(tournee7.id), isFalse);
    });
  });
}
