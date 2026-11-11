import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/join/join_request_notifier.dart';
import 'package:tournee_calendriers/presentation/join/join_request_state.dart';
import 'package:tournee_calendriers/presentation/launch/launch_place.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show julieId;
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_sector_directory.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';

/// Lets every pending future run.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  /// Julie's request to join the 49, waiting.
  final request49 = summaryOf('t49', 49, status: MemberStatus.pending);
  final t49 = SectorId('t49');
  const waiting49 = RequestWaiting(
    number: 49,
    centre: 'CS Villefranche',
    canLeave: false,
  );

  late FakeSectorDirectory directory;
  late FakeMemberAccount account;
  late FakeMySectorsStore store;
  late ProviderContainer container;

  /// Opens « Demande envoyée » for the 49 on a phone holding [mine].
  Future<void> open(MySectors mine) async {
    store = FakeMySectorsStore(mine);
    container = ProviderContainer(
      overrides: [
        memberAccountProvider.overrideWithValue(account),
        sectorDirectoryProvider.overrideWithValue(directory),
        mySectorsStoreProvider.overrideWithValue(store),
        // « Mes secteurs » follows the teams of the secteurs not open.
        sectorRepositoryProvider.overrideWithValue(FakeSectorRepository()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(joinRequestProvider(t49), (_, _) {});
    await _settle();
  }

  JoinRequestState state() => container.read(joinRequestProvider(t49));
  JoinRequestNotifier screen() =>
      container.read(joinRequestProvider(t49).notifier);

  setUp(() {
    directory = FakeSectorDirectory();
    account = FakeMemberAccount(signedInMember: julieId);
  });

  group('while the request waits', () {
    test('should show the secteur asked for, with no way out', () async {
      await open(MySectors.none.remember(request49));

      expect(state(), waiting49);
      expect(directory.watched, [(t49, julieId)]);
    });

    test('should offer a way back when a secteur is open', () async {
      await open(
        valueOf(
          MySectors.none
              .remember(sector12)
              .remember(request49)
              .open(sector12.id),
        ),
      );

      expect(state(), waiting49.withCanLeave(true));
    });

    test(
      'should offer a way back once another secteur is opened meanwhile',
      () async {
        await open(MySectors.none.remember(sector12).remember(request49));
        expect(state(), waiting49);

        await store.save(valueOf(store.mySectors.open(sector12.id)));
        await _settle();

        expect(state(), waiting49.withCanLeave(true));
      },
    );

    test('should keep waiting while the server says it is pending', () async {
      await open(MySectors.none.remember(request49));

      directory.answer(t49, MemberStatus.pending);
      await _settle();

      expect(state(), waiting49);
    });

    test(
      'should keep waiting offline: no answer comes, nothing is dropped',
      () async {
        await open(MySectors.none.remember(request49));

        await _settle();

        expect(state(), waiting49);
        expect(store.saves, isEmpty);
      },
    );

    test('should keep waiting when the listener fails', () async {
      await open(MySectors.none.remember(request49));

      directory.fail(t49);
      await _settle();

      expect(state(), waiting49);
      expect(store.mySectors.find(t49), request49);
    });
  });

  group('accepted', () {
    test('should open the secteur and show the start screen', () async {
      await open(MySectors.none.remember(sector12).remember(request49));

      directory.answer(t49, MemberStatus.active);
      await _settle();

      expect(state(), const RequestAccepted());
      expect(store.mySectors.current, request49.accepted());
      expect(store.mySectors.sectors, [sector12, request49.accepted()]);
    });

    test(
      'should open the secteur when it was accepted before the screen opened',
      () async {
        await open(MySectors.none.remember(request49.accepted()));

        expect(state(), const RequestAccepted());
        expect(store.mySectors.currentId, t49);
      },
    );
  });

  group('refused', () {
    test('should say refused and go back to « Bienvenue »', () async {
      await open(MySectors.none.remember(request49));

      directory.answer(t49, null);
      await _settle();

      expect(
        state(),
        const RequestClosed(refused: true, next: LaunchOnWelcome()),
      );
      expect(store.mySectors, MySectors.none);
    });

    test('should go back to the start screen when the phone knows another '
        'secteur', () async {
      await open(MySectors.none.remember(sector12).remember(request49));

      directory.answer(t49, null);
      await _settle();

      expect(
        state(),
        const RequestClosed(refused: true, next: LaunchOnStreets()),
      );
    });

    test('should go on to another request still waiting', () async {
      await open(MySectors.none.remember(sector7).remember(request49));

      directory.answer(t49, null);
      await _settle();

      expect(
        state(),
        RequestClosed(refused: true, next: LaunchOnRequest(sector7.id)),
      );
    });

    test('should not say refused when the request was gone before the screen '
        'opened', () async {
      await open(MySectors.none);

      expect(
        state(),
        const RequestClosed(refused: false, next: LaunchOnWelcome()),
      );
    });
  });

  group('« Annuler la demande »', () {
    test('should withdraw the request and go back, not refused', () async {
      await open(MySectors.none.remember(request49));

      await screen().cancel();
      await _settle();

      expect(directory.cancelled, [(t49, julieId)]);
      expect(store.mySectors, MySectors.none);
      expect(
        state(),
        const RequestClosed(refused: false, next: LaunchOnWelcome()),
      );
    });

    test('should not say refused when the server then drops it', () async {
      await open(MySectors.none.remember(request49));

      await screen().cancel();
      directory.answer(t49, null);
      await _settle();

      expect(
        state(),
        const RequestClosed(refused: false, next: LaunchOnWelcome()),
      );
    });
  });

  group('values', () {
    test('should equal states with the same values only', () {
      expect(waiting49, waiting49.withCanLeave(false));
      expect(waiting49.hashCode, waiting49.withCanLeave(false).hashCode);
      expect(waiting49, isNot(waiting49.withCanLeave(true)));
      expect(
        waiting49,
        isNot(
          const RequestWaiting(
            number: 12,
            centre: 'CS Villefranche',
            canLeave: false,
          ),
        ),
      );
      expect(
        waiting49.toString(),
        'RequestWaiting(49, CS Villefranche, false)',
      );
      const closed = RequestClosed(refused: true, next: LaunchOnWelcome());
      expect(
        closed.hashCode,
        const RequestClosed(refused: true, next: LaunchOnWelcome()).hashCode,
      );
      expect(
        closed,
        isNot(const RequestClosed(refused: false, next: LaunchOnWelcome())),
      );
      expect(
        closed,
        isNot(const RequestClosed(refused: true, next: LaunchOnStreets())),
      );
      expect(closed.toString(), startsWith('RequestClosed(true, '));
    });
  });
}
