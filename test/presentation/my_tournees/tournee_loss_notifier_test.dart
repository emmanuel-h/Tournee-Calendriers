import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_loss.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_tournees/tournee_loss_notice.dart';
import 'package:tournee_calendriers/presentation/my_tournees/tournee_loss_notifier.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/results.dart';

/// The 49 (open), the 12 and the pending 7.
MyTournees _manusPhone() => valueOf(
  MyTournees.none
      .remember(tournee49)
      .remember(tournee12)
      .remember(tournee7)
      .open(tournee49.id),
);

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

  test('should follow each tournée the member is in, as the signed-in '
      'member, and not their requests', () {
    final container = containerWith(_manusPhone());

    container.read(tourneeLossProvider);

    expect(directory.memberships, [(tournee49, manuId), (tournee12, manuId)]);
  });

  test('should tell nothing while no tournée is lost', () {
    final container = containerWith(_manusPhone());

    expect(container.read(tourneeLossProvider), isNull);
  });

  test('should forget the open tournée the member was removed from, open '
      'none, and tell it', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);

    directory.lose(tournee49.id, TourneeLoss.removed);
    await pumpEventQueue();

    expect(
      container.read(tourneeLossProvider),
      TourneeLossNotice(
        tournee: tournee49.id,
        number: 49,
        loss: TourneeLoss.removed,
        wasOpen: true,
      ),
    );
    expect(store.saves.single.tournees, [tournee12, tournee7]);
    expect(store.saves.single.current, isNull);
    expect(directory.isFollowing(tournee49.id), isFalse);
  });

  test('should forget another tournée deleted, keep the open one, and tell '
      'it', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);

    directory.lose(tournee12.id, TourneeLoss.deleted);
    await pumpEventQueue();

    expect(
      container.read(tourneeLossProvider),
      TourneeLossNotice(
        tournee: tournee12.id,
        number: 12,
        loss: TourneeLoss.deleted,
        wasOpen: false,
      ),
    );
    expect(store.saves.single.tournees, [tournee49, tournee7]);
    expect(store.saves.single.current, tournee49);
  });

  test('should keep every tournée while offline: the server says '
      'nothing', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);

    await pumpEventQueue();

    expect(container.read(tourneeLossProvider), isNull);
    expect(store.saves, isEmpty);
    expect(directory.isFollowing(tournee49.id), isTrue);
  });

  test('should keep the tournée when its listener fails', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);

    directory.failMembership(tournee49.id);
    await pumpEventQueue();

    expect(container.read(tourneeLossProvider), isNull);
    expect(store.saves, isEmpty);
  });

  test('should tell nothing for a tournée the phone forgot meanwhile '
      '(left, deleted from this phone)', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);
    // Forgotten without a change heard yet: the loss still arrives.
    store.myTournees = _manusPhone().forget(tournee49.id);

    directory.lose(tournee49.id, TourneeLoss.removed);
    await pumpEventQueue();

    expect(container.read(tourneeLossProvider), isNull);
    expect(store.saves, isEmpty);
  });

  test('should follow a tournée the member is accepted in later', () async {
    final container = containerWith(MyTournees.none.remember(tournee7));
    container.read(tourneeLossProvider);
    expect(directory.memberships, isEmpty);

    await store.save(MyTournees.none.remember(tournee7.accepted()));

    expect(directory.memberships, [(tournee7.accepted(), manuId)]);
  });

  test('should follow a tournée once however often the list changes', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);

    await store.save(valueOf(_manusPhone().open(tournee12.id)));

    expect(directory.memberships, hasLength(2));
  });

  test('should stop following when the app goes away', () {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);

    container.dispose();

    expect(directory.isFollowing(tournee49.id), isFalse);
    expect(directory.isFollowing(tournee12.id), isFalse);
  });

  test('should tell nothing once the app has gone away', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);
    // The app goes away while the phone forgets the tournée.
    store.changes.listen((_) => container.dispose());

    directory.lose(tournee49.id, TourneeLoss.removed);
    await pumpEventQueue();

    expect(store.saves.single.find(tournee49.id), isNull);
  });

  group('TourneeLossNotice', () {
    TourneeLossNotice notice({
      String tournee = 't49',
      int number = 49,
      TourneeLoss loss = TourneeLoss.removed,
      bool wasOpen = true,
    }) => TourneeLossNotice(
      tournee: TourneeId(tournee),
      number: number,
      loss: loss,
      wasOpen: wasOpen,
    );

    test('should compare notices field by field', () {
      expect(notice(), notice());
      expect(notice().hashCode, notice().hashCode);
      for (final other in [
        notice(tournee: 't50'),
        notice(number: 50),
        notice(loss: TourneeLoss.deleted),
        notice(wasOpen: false),
      ]) {
        expect(notice() == other, isFalse, reason: '$other');
      }
    });

    test('should name the tournée and the loss', () {
      expect('${notice()}', 'TourneeLossNotice(t49, 49, removed, open)');
      expect(
        '${notice(wasOpen: false)}',
        'TourneeLossNotice(t49, 49, removed, closed)',
      );
    });
  });
}
