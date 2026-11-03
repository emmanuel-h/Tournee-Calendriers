import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';
import '../support/buttons.dart';
import '../support/navigation.dart';

const _nbsp = ' ';

/// A ledger that cannot be read.
final class _BrokenLedger implements RoundLedger {
  @override
  Future<void> record(SectorId s, CampaignYear c, RoundSummary r) async {}

  @override
  Stream<List<RoundSummary>> watch(SectorId s, CampaignYear c) =>
      Stream.error(StateError('unreadable'));
}

/// A tournée of the 49 named [id], from [start] to [end] (the phone's
/// time), [houses] visited, with [donations].
RoundSummary _round(
  String id,
  DateTime start,
  DateTime end,
  int houses,
  List<Donation> donations,
) => RoundSummary(
  id: RoundId(id),
  startedAt: start.toUtc(),
  endedAt: end.toUtc(),
  housesVisited: houses,
  totals: DonationTotals.of(donations),
);

/// Saturday 24 October, 14:05 → 18:20: 23 houses, 10 € and 20 € in cash,
/// 5 € by cheque, a free calendar.
final _saturday = _round(
  'sat',
  DateTime(2026, 10, 24, 14, 5),
  DateTime(2026, 10, 24, 18, 20),
  23,
  [cash(1000), cash(2000), cheque(500), offered],
);

/// Friday 23 October, 17:30 → 19:45: 14 houses, 7,50 € by card.
final _friday = _round(
  'fri',
  DateTime(2026, 10, 23, 17, 30),
  DateTime(2026, 10, 23, 19, 45),
  14,
  [card(750)],
);

void main() {
  /// Équipe of the 49 over the start screen, on the phone of [member],
  /// the tournées [validated] in the ledger (or [ledger]).
  Future<void> pumpTeam(
    WidgetTester tester, {
    MemberId? member,
    List<RoundSummary> validated = const [],
    RoundLedger? ledger,
  }) async {
    // A phone's screen (the mockup's), so the collecte row shows.
    tester.view
      ..physicalSize = const Size(393 * 3, 852 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final kept = member == samId
        ? summaryOf('t49', 49, status: MemberStatus.visiting)
        : sector49;
    final fake = FakeRoundLedger();
    for (final summary in validated) {
      await fake.record(sector49.id, sector49.campaign, summary);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          mySectors: FakeMySectorsStore(
            valueOf(MySectors.none.remember(kept).open(sector49.id)),
          ),
          sectors: FakeSectorRepository([team()]),
          ledger: ledger ?? fake,
          member: member ?? leaId,
          admins: FakeAdminStatus(
            phoneIsAdmin: member == samId,
            admins: [manuId, samId],
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    unawaitedPush(
      GoRouter.of(tester.element(find.byType(Scaffold).first)),
      AppRoutes.team,
    );
    await tester.pumpAndSettle();
  }

  /// Équipe, then « Collecte 2026 » from its row.
  Future<void> pumpCollecte(
    WidgetTester tester, {
    List<RoundSummary> validated = const [],
    RoundLedger? ledger,
  }) async {
    await pumpTeam(tester, validated: validated, ledger: ledger);
    if (ledger != null) {
      unawaitedPush(
        GoRouter.of(tester.element(find.byType(Scaffold).last)),
        AppRoutes.collecte,
      );
    } else {
      await tapVisible(tester, find.byKey(const Key('team.collecte')));
    }
    await tester.pumpAndSettle();
  }

  /// The texts of the line [key], joined by « | ».
  String lineText(WidgetTester tester, String key) => [
    for (final text in tester.widgetList<Text>(
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
    ))
      text.data,
  ].join(' | ');

  /// The texts of the tournée [id]'s row, joined by « | ».
  String roundText(WidgetTester tester, String id) => [
    for (final text in tester.widgetList<Text>(
      find.descendant(
        of: find.byKey(ValueKey('collecte.round.$id')),
        matching: find.byType(Text),
      ),
    ))
      text.data,
  ].join(' | ');

  group('Équipe', () {
    testWidgets('should show the money of the validated tournées under '
        '« COLLECTE 2026 », never per member', (tester) async {
      await pumpTeam(tester, validated: [_saturday, _friday]);

      expect(find.text('COLLECTE 2026'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('team.collecte.raised'))).data,
        '42,50$_nbsp€ récoltés',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('team.collecte.dons'))).data,
        '4${_nbsp}dons en 2${_nbsp}tournées',
      );
      expect(
        find.bySemanticsLabel(
          'Collecte 2026$_nbsp: 42,50$_nbsp€ récoltés, '
          '4${_nbsp}dons en 2${_nbsp}tournées',
        ),
        findsOneWidget,
      );
      // No member's row says anything of money.
      for (final member in [manuId, leaId]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('team.member.${member.value}')),
            matching: find.textContaining('€'),
          ),
          findsNothing,
        );
      }
    });

    testWidgets('should say « 0 don en 0 tournée » before the first one', (
      tester,
    ) async {
      await pumpTeam(tester);

      expect(
        tester.widget<Text>(find.byKey(const Key('team.collecte.raised'))).data,
        '0$_nbsp€ récoltés',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('team.collecte.dons'))).data,
        '0${_nbsp}don en 0${_nbsp}tournée',
      );
    });

    testWidgets('should show the collecte to an admin visiting the secteur', (
      tester,
    ) async {
      await pumpTeam(tester, member: samId, validated: [_friday]);

      expect(
        tester.widget<Text>(find.byKey(const Key('team.collecte.dons'))).data,
        '1${_nbsp}don en 1${_nbsp}tournée',
      );
    });

    testWidgets('should show no collecte row when it cannot be read', (
      tester,
    ) async {
      await pumpTeam(tester, ledger: _BrokenLedger());

      expect(find.byKey(const Key('team.collecte')), findsNothing);
      expect(find.text('COLLECTE 2026'), findsNothing);
    });
  });

  group('Collecte', () {
    testWidgets('should open from Équipe on the totals per method, the '
        'free calendars and the total', (tester) async {
      await pumpCollecte(tester, validated: [_friday, _saturday]);

      expect(find.text('Collecte 2026'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('collecte.subtitle'))).data,
        'Secteur 49 · tournées validées',
      );
      expect(find.text('TOTAL DES 2${_nbsp}TOURNÉES'), findsOneWidget);
      expect(
        lineText(tester, 'collecte.cash'),
        'Espèces | 2${_nbsp}dons | 30$_nbsp€',
      );
      expect(
        lineText(tester, 'collecte.cheque'),
        'Chèques | 1${_nbsp}don | 5$_nbsp€',
      );
      expect(
        lineText(tester, 'collecte.card'),
        'Carte bancaire | 1${_nbsp}don | 7,50$_nbsp€',
      );
      expect(lineText(tester, 'collecte.free'), 'Calendriers offerts | 1 | ');
      expect(
        lineText(tester, 'collecte.total'),
        'Total | 4${_nbsp}dons | 42,50$_nbsp€',
      );
      expect(
        find.text(
          'Une tournée validée ne peut plus être modifiée. Les dons ne sont '
          'jamais associés à une adresse.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('should list the tournées newest first, without their '
        'member, folded', (tester) async {
      await pumpCollecte(tester, validated: [_friday, _saturday]);

      expect(find.text('TOURNÉES'), findsOneWidget);
      expect(
        roundText(tester, 'sat'),
        'Sam. 24 oct. · 14:05 → 18:20 | 23${_nbsp}maisons, 3${_nbsp}dons | '
        '35$_nbsp€ | ▸',
      );
      expect(
        roundText(tester, 'fri'),
        'Ven. 23 oct. · 17:30 → 19:45 | 14${_nbsp}maisons, 1${_nbsp}don | '
        '7,50$_nbsp€ | ▸',
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('collecte.round.sat'))).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('collecte.round.fri')))
              .dy,
        ),
      );
      expect(find.byKey(const Key('collecte.round.methods')), findsNothing);
      expect(find.textContaining('Léa'), findsNothing);
    });

    testWidgets('should unfold a tournée\'s methods on a tap, and fold them '
        'on the next', (tester) async {
      await pumpCollecte(tester, validated: [_friday, _saturday]);
      final saturday = find.bySemanticsLabel(
        'Sam. 24 oct. · 14:05 → 18:20, 35$_nbsp€, afficher le détail',
      );
      expect(saturday, findsOneWidget);

      await tester.tap(saturday);
      await tester.pumpAndSettle();

      final methods = find.byKey(const Key('collecte.round.methods'));
      expect(methods, findsOneWidget);
      expect(
        [
          for (final text in tester.widgetList<Text>(
            find.descendant(of: methods, matching: find.byType(Text)),
          ))
            text.data,
        ],
        [
          'Espèces',
          '2${_nbsp}dons',
          '30$_nbsp€',
          'Chèques',
          '1${_nbsp}don',
          '5$_nbsp€',
          'Carte bancaire',
          '0${_nbsp}don',
          '0$_nbsp€',
        ],
      );
      expect(roundText(tester, 'sat'), contains('35$_nbsp€ | ▾ | Espèces'));
      final unfolded = find.bySemanticsLabel(
        'Sam. 24 oct. · 14:05 → 18:20, 35$_nbsp€, masquer le détail',
      );
      expect(unfolded, findsOneWidget);
      expect(roundText(tester, 'fri'), endsWith('| ▸'));

      await tester.tap(find.byKey(const Key('collecte.round.toggle')).first);
      await tester.pumpAndSettle();

      expect(methods, findsNothing);
    });

    testWidgets('should say « Total de la tournée » for one', (tester) async {
      await pumpCollecte(tester, validated: [_friday]);
      expect(find.text('TOTAL DE LA TOURNÉE'), findsOneWidget);
    });

    testWidgets('should show an empty collecte before the first tournée', (
      tester,
    ) async {
      await pumpCollecte(tester);

      expect(find.text('TOTAL DES TOURNÉES'), findsOneWidget);
      expect(
        lineText(tester, 'collecte.total'),
        'Total | 0${_nbsp}don | 0$_nbsp€',
      );
      expect(find.byKey(const Key('collecte.round.toggle')), findsNothing);
    });

    testWidgets('should say when the collecte cannot be shown', (tester) async {
      await pumpCollecte(tester, ledger: _BrokenLedger());

      expect(
        find.text('La collecte ne peut pas être affichée.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('collecte.subtitle')), findsNothing);
    });
  });
}
