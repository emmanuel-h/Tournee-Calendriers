import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_view_preferences.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';

final _id = StreetId('lilas');

/// The Main mockup in short: 1 to do, 3 done, 3bis nobody home, 5 to come
/// back, 7 with a note; 2 done, 4 to do, 8 a building with 1 of its 2
/// doors done.
final _lilas = valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('1')),
      House(number: n('3'), status: VisitStatus.done),
      House(number: n('3bis'), status: VisitStatus.nobodyHome),
      House(number: n('5'), comeBack: comeBack('après 19h')),
      House(number: n('7'), note: note('chien')),
      House(number: n('2'), status: VisitStatus.done),
      House(number: n('4')),
      House(
        number: n('8'),
        building: building(topFloor: 0, doors: 2).withDwelling(
          escA,
          0,
          Dwelling(label: d('01'), status: VisitStatus.done),
        ),
      ),
    ],
  ),
);

Finder _tile(String number) => find.byKey(ValueKey('street.tile.$number'));

void main() {
  late FakeStreetRepository streets;
  late FakeStreetViewPreferences preferences;

  /// Starts the app on « Mes rues » with [street] on the phone, then opens
  /// [location] (the street screen of [street] by default), as the start
  /// list does.
  Future<void> openStreet(
    WidgetTester tester, {
    Street? street,
    String? location,
  }) async {
    streets = FakeStreetRepository([street ?? _lilas]);
    preferences = FakeStreetViewPreferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(streets: streets, preferences: preferences),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    unawaitedPush(router, location ?? AppRoutes.streetOf(_id));
    await tester.pumpAndSettle();
  }

  String labelOf(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).label;

  testWidgets(
    'should cycle the status with a tick and say it when a house is tapped',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final platformCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call);
          return null;
        },
      );
      await openStreet(tester);
      expect(labelOf(tester, _tile('1')), 'Numéro 1, à faire');
      expect(find.byKey(const Key('street.hint')), findsOneWidget);

      await tester.tap(_tile('1'));
      await tester.pumpAndSettle();

      expect(labelOf(tester, _tile('1')), 'Numéro 1, fait');
      expect(
        platformCalls.where((call) => call.method == 'HapticFeedback.vibrate'),
        [
          isA<MethodCall>().having(
            (call) => call.arguments,
            'type',
            'HapticFeedbackType.lightImpact',
          ),
        ],
      );
      expect(
        tester.takeAnnouncements().map((announcement) => announcement.message),
        ['Numéro 1, fait'],
      );
      expect(find.text('1 → Fait'), findsOneWidget);
      expect(find.byKey(const Key('street.hint')), findsNothing);
      expect(
        labelOf(tester, find.byKey(const Key('street.counts'))),
        '4 sur 9 faits, 1 personne, 1 à repasser',
      );

      await tester.tap(_tile('1'));
      await tester.pumpAndSettle();

      expect(labelOf(tester, _tile('1')), 'Numéro 1, personne');
      expect(
        tester.takeAnnouncements().map((announcement) => announcement.message),
        ['Numéro 1, personne'],
      );
      // The new snackbar replaced the first one.
      expect(find.text('1 → Personne'), findsOneWidget);
      expect(find.text('1 → Fait'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'should put the house back and the hint again when Annuler is tapped',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openStreet(tester);
      await tester.tap(_tile('5'));
      await tester.pumpAndSettle();
      expect(labelOf(tester, _tile('5')), 'Numéro 5, fait');

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(labelOf(tester, _tile('5')), 'Numéro 5, à faire, repasser');
      expect(streets[_id]!.houses, _lilas.houses);
      expect(find.text('5 → Fait'), findsNothing);
      expect(find.byKey(const Key('street.hint')), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'should leave the snackbar after 4 s and keep the mark when not undone',
    (tester) async {
      await openStreet(tester);
      await tester.tap(_tile('4'));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('4 → Fait'), findsNothing);
      expect(find.byKey(const Key('street.hint')), findsOneWidget);
      expect(streets[_id]!.houses[1].status, VisitStatus.done);
    },
  );

  testWidgets(
    'should hide the done tiles and remember it when Masquer faits is on',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openStreet(tester);
      final toggle = find.byKey(const Key('street.hideDone'));
      expect(
        tester.getSemantics(toggle).flagsCollection.isToggled.toBoolOrNull(),
        false,
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(_tile('3'), findsNothing);
      expect(_tile('2'), findsNothing);
      expect(_tile('1'), findsOneWidget);
      expect(_tile('3bis'), findsOneWidget);
      expect(_tile('8'), findsOneWidget);
      // The counts still cover the whole street.
      expect(
        labelOf(tester, find.byKey(const Key('street.counts'))),
        '3 sur 9 faits, 1 personne, 1 à repasser',
      );
      expect(
        tester.getSemantics(toggle).flagsCollection.isToggled.toBoolOrNull(),
        true,
      );
      expect(preferences.writes, [(_id, true)]);
      semantics.dispose();
    },
  );

  testWidgets(
    'should show a single wide column when the street has one side only',
    (tester) async {
      await openStreet(
        tester,
        street: valueOf(
          Street.create(
            id: _id,
            name: 'Impasse des Lilas',
            commune: villefranche,
            houses: [
              House(number: n('1')),
              House(number: n('3')),
            ],
          ),
        ),
      );

      expect(find.text('CÔTÉ IMPAIR'), findsOneWidget);
      expect(find.text('CÔTÉ PAIR'), findsNothing);
      final screen = tester.getSize(find.byType(Scaffold).last);
      expect(tester.getSize(_tile('1')).width, screen.width - 2 * 16);
      expect(
        tester.getTopLeft(_tile('3')).dy,
        tester.getTopLeft(_tile('1')).dy + 70,
      );
    },
  );

  testWidgets('should say the street is gone when it is not on the phone', (
    tester,
  ) async {
    await openStreet(tester, location: AppRoutes.streetOf(StreetId('autre')));

    expect(find.text("Cette rue n'est plus sur ce téléphone."), findsOneWidget);
    expect(find.byKey(const Key('street.edit')), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    // A link naming no street says the same.
    final router = GoRouter.of(tester.element(find.byType(Scaffold).last));
    unawaitedPush(router, AppRoutes.street);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Rue'), findsOneWidget);
    expect(find.text("Cette rue n'est plus sur ce téléphone."), findsOneWidget);
  });

  testWidgets('should open the edit mode of the street when ✏ is tapped', (
    tester,
  ) async {
    await openStreet(tester);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).last));

    await tester.tap(find.byKey(const Key('street.edit')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Modifier la rue'), findsOneWidget);
    expect(router.state.uri.toString(), AppRoutes.editStreetOf(_id));
  });
}

/// `push` returns a `Future` that ends when the pushed screen is closed;
/// the tests do not wait for it.
void unawaitedPush(GoRouter router, String location) {
  router.push<void>(location).ignore();
}
