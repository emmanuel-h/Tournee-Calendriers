import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/presentation/all_tournees/all_tournees_notifier.dart';
import 'package:tournee_calendriers/presentation/all_tournees/all_tournees_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/results.dart';

/// Tournée [number] of [centre] (a station of Villefranche) in [year].
TourneeOverview overview(
  String id,
  int number, {
  String centre = 'CS Villefranche',
  int year = 2026,
  int members = 3,
  int requests = 0,
  bool mine = false,
}) => TourneeOverview(
  id: TourneeId(id),
  number: valueOf(TourneeNumber.create(number)),
  centre: valueOf(RescueCentre.create(centre)),
  campaign: valueOf(CampaignYear.create(year)),
  activeMembers: members,
  pendingRequests: requests,
  callerIsActive: mine,
);

void main() {
  late FakeTourneeDirectory directory;
  late FakeMemberAccount account;
  late FakeMyTourneesStore store;

  ProviderContainer open() {
    final container = ProviderContainer(
      overrides: [
        tourneeDirectoryProvider.overrideWithValue(directory),
        memberAccountProvider.overrideWithValue(account),
        myTourneesStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    // Kept alive as the screen keeps it while it shows.
    container.listen(allTourneesProvider, (_, _) {});
    return container;
  }

  setUp(() {
    directory = FakeTourneeDirectory();
    account = FakeMemberAccount(signedInMember: samId);
    store = FakeMyTourneesStore(
      valueOf(MyTournees.none.remember(tournee49).open(tournee49.id)),
    );
  });

  test('should be loading until the server answers', () {
    expect(open().read(allTourneesProvider), const AllTourneesLoading());
  });

  test('should group the tournées by station, stations by name, tournées '
      'by number then year', () async {
    directory.overviews = [
      overview('t50', 50, mine: true, members: 1),
      overview('t12', 12, centre: 'CS Villefranche Nord', requests: 2),
      overview('t49b', 49, year: 2027, members: 0),
      overview('t49', 49),
      overview('t7', 7, centre: 'CIS Villefranche Est'),
      // The same station written otherwise: one group, the first name.
      overview('t13', 13, centre: 'Centre de secours de Villefranche Nord'),
    ];
    final container = open();
    await pumpEventQueue();

    final state = container.read(allTourneesProvider) as AllTourneesShown;

    expect(state.count, 6);
    expect(state.groups.map((group) => group.centre), [
      'CS Villefranche',
      'CIS Villefranche Est',
      'CS Villefranche Nord',
    ]);
    expect(state.groups.first.rows, [
      OverviewRow(
        id: TourneeId('t49'),
        number: 49,
        campaign: 2026,
        members: 3,
        waitingRequests: 0,
        iAmIn: false,
      ),
      OverviewRow(
        id: TourneeId('t49b'),
        number: 49,
        campaign: 2027,
        members: 0,
        waitingRequests: 0,
        iAmIn: false,
      ),
      OverviewRow(
        id: TourneeId('t50'),
        number: 50,
        campaign: 2026,
        members: 1,
        waitingRequests: 0,
        iAmIn: true,
      ),
    ]);
    expect(state.groups.last.rows.map((row) => row.id.value), ['t12', 't13']);
    expect(state.groups.last.rows.first.waitingRequests, 2);
  });

  test('should show an empty list when the app has no tournée', () async {
    final container = open();
    await pumpEventQueue();

    final state = container.read(allTourneesProvider) as AllTourneesShown;
    expect(state.count, 0);
    expect(state.groups, isEmpty);
  });

  test('should say when the server cannot be reached, then try '
      'again', () async {
    directory.offline = true;
    final container = open();
    await pumpEventQueue();

    expect(container.read(allTourneesProvider), const AllTourneesOffline());

    directory
      ..offline = false
      ..overviews = [overview('t49', 49)];
    final retrying = container.read(allTourneesProvider.notifier).retry();
    expect(container.read(allTourneesProvider), const AllTourneesLoading());
    await retrying;

    expect(container.read(allTourneesProvider), isA<AllTourneesShown>());
  });

  test('should say when the server says the phone is no longer an '
      'admin\'s', () async {
    directory.notAdmin = true;
    final container = open();
    await pumpEventQueue();

    expect(container.read(allTourneesProvider), const AllTourneesNotAdmin());
  });

  test('should drop the answer once the screen has closed', () async {
    // The phone signs in first; the screen closes meanwhile.
    account = FakeMemberAccount(nextMember: samId)..gate = Completer<void>();
    final container = open();
    await pumpEventQueue();

    container.dispose();
    account.gate.complete();
    await pumpEventQueue();

    expect(directory.allAsked, [samId]);
  });

  test('should open a tournée the admin is not in as visited', () async {
    directory.overviews = [overview('t12', 12)];
    final container = open();
    await pumpEventQueue();

    await container.read(allTourneesProvider.notifier).open(TourneeId('t12'));

    expect(
      store.myTournees.current,
      summaryOf('t12', 12, status: MemberStatus.visiting),
    );
  });

  test('should open nothing for a tournée the list does not hold', () async {
    final container = open();
    await pumpEventQueue();

    await container.read(allTourneesProvider.notifier).open(TourneeId('t99'));

    expect(store.saves, isEmpty);
  });

  test('should compare its values field by field', () {
    OverviewRow row({int number = 12, bool iAmIn = false}) => OverviewRow(
      id: TourneeId('t12'),
      number: number,
      campaign: 2026,
      members: 3,
      waitingRequests: 1,
      iAmIn: iAmIn,
    );

    expect(row(), row());
    expect(row().hashCode, row().hashCode);
    expect(row(number: 13), isNot(row()));
    expect(row(iAmIn: true), isNot(row()));
    for (final other in [
      OverviewRow(
        id: TourneeId('t13'),
        number: 12,
        campaign: 2026,
        members: 3,
        waitingRequests: 1,
        iAmIn: false,
      ),
      OverviewRow(
        id: TourneeId('t12'),
        number: 12,
        campaign: 2027,
        members: 3,
        waitingRequests: 1,
        iAmIn: false,
      ),
      OverviewRow(
        id: TourneeId('t12'),
        number: 12,
        campaign: 2026,
        members: 4,
        waitingRequests: 1,
        iAmIn: false,
      ),
      OverviewRow(
        id: TourneeId('t12'),
        number: 12,
        campaign: 2026,
        members: 3,
        waitingRequests: 2,
        iAmIn: false,
      ),
    ]) {
      expect(other, isNot(row()));
    }
    final group = CentreGroup(centre: 'CS Villefranche', rows: [row()]);
    expect(group, CentreGroup(centre: 'CS Villefranche', rows: [row()]));
    expect(
      group.hashCode,
      CentreGroup(centre: 'CS Villefranche', rows: [row()]).hashCode,
    );
    expect(group, isNot(CentreGroup(centre: 'CS Anse', rows: [row()])));
    expect(group, isNot(CentreGroup(centre: 'CS Villefranche', rows: [])));
    expect(
      AllTourneesShown([group]),
      AllTourneesShown([
        CentreGroup(centre: 'CS Villefranche', rows: [row()]),
      ]),
    );
    expect(
      AllTourneesShown([group]).hashCode,
      AllTourneesShown([
        CentreGroup(centre: 'CS Villefranche', rows: [row()]),
      ]).hashCode,
    );
    expect(AllTourneesShown([group]), isNot(AllTourneesShown(const [])));
    expect(const AllTourneesLoading(), isNot(const AllTourneesOffline()));
    expect(const AllTourneesOffline(), isNot(const AllTourneesNotAdmin()));
  });
}
