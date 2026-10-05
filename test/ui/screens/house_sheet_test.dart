import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';

final _id = StreetId('lilas');

/// 1 to do, 5 « repasser » « après 19h », 7 to do.
final _lilas = valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('1')),
      House(
        number: n('5'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('après 19h'),
      ),
      House(number: n('7')),
    ],
  ),
);

Finder _tile(String number) => find.byKey(ValueKey('street.tile.$number'));

/// A family emoji: one symbol on screen, five code points.
const _family = '👨‍👩‍👧';

void main() {
  late FakeStreetRepository streets;

  /// Opens the street screen of [_lilas], then holds the tile of [number].
  Future<void> holdTile(WidgetTester tester, String number) async {
    // A phone-sized screen (411 × 914 dp): on the default 800 × 600 test
    // surface the sheet reaches the top, leaving no dimmed street to tap.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    streets = FakeStreetRepository([_lilas]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(streets: streets),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push<void>(AppRoutes.streetOf(_id)).ignore();
    await tester.pumpAndSettle();
    await tester.longPress(_tile(number));
    await tester.pumpAndSettle();
  }

  /// Taps the dimmed street above the sheet, which closes it.
  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
  }

  House stored(String number) =>
      streets[_id]!.houses.singleWhere((house) => house.number == n(number));

  SemanticsData semanticsOf(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).getSemanticsData();

  testWidgets(
    'should show ↻ on the tile when Repasser is chosen in the held house sheet',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await holdTile(tester, '1');
      expect(find.byKey(const Key('house.number')), findsOneWidget);
      expect(find.text('Rue des Lilas'), findsWidgets);
      // No free note: too sensitive to keep about people (PLAN §8.3).
      expect(find.byKey(const Key('house.note.field')), findsNothing);
      expect(find.textContaining('Note'), findsNothing);
      expect(find.textContaining("N'écrivez"), findsNothing);
      expect(find.byKey(const Key('house.lastChange')), findsNothing);
      final hint = find.byKey(const Key('house.comeBackHint.field'));
      expect(tester.widget<TextField>(hint).enabled, isFalse);
      expect(find.text('Quand repasser\u00a0?'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('house.status.comeBack')));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(hint).enabled, isTrue);
      expect(
        semanticsOf(
          tester,
          find.byKey(const ValueKey('house.status.comeBack')),
        ).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      await tester.enterText(hint, 'après 19h');
      await closeSheet(tester);

      expect(find.byKey(const Key('house.number')), findsNothing);
      expect(tester.getSemantics(_tile('1')).label, 'Numéro 1, repasser');
      expect(stored('1').status, VisitStatus.comeBack);
      expect(stored('1').comeBack, comeBack('après 19h'));
      semantics.dispose();
    },
  );

  testWidgets(
    'should grey the hint field and drop its hint when Fait is chosen',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await holdTile(tester, '5');
      final hint = find.byKey(const Key('house.comeBackHint.field'));
      expect(tester.widget<TextField>(hint).enabled, isTrue);
      expect(find.text('après 19h'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('house.status.done')));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(hint).enabled, isFalse);
      expect(find.text('après 19h'), findsNothing);
      expect(
        semanticsOf(
          tester,
          find.byKey(const ValueKey('house.status.done')),
        ).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      final local = twoPm.toLocal();
      String two(int value) => value.toString().padLeft(2, '0');
      expect(
        find.text('Modifié à ${two(local.hour)}:${two(local.minute)}'),
        findsOneWidget,
      );
      expect(stored('5').status, VisitStatus.done);
      expect(stored('5').comeBack, isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'should keep the sheet and its fields in place whichever of the four '
    'statuses is chosen',
    (tester) async {
      await holdTile(tester, '1');
      // The house was never changed: the first choice stamps it, and the
      // line « Modifié à … » appears in a place kept for it.
      Rect sheet() => tester.getRect(find.byType(BottomSheet));
      Rect hint() =>
          tester.getRect(find.byKey(const Key('house.comeBackHint.field')));
      Rect action() =>
          tester.getRect(find.byKey(const Key('house.toBuilding')));
      final before = (sheet(), hint(), action());

      for (final status in [
        VisitStatus.done,
        VisitStatus.nobodyHome,
        VisitStatus.comeBack,
        VisitStatus.toDo,
      ]) {
        await tester.tap(find.byKey(ValueKey('house.status.${status.name}')));
        await tester.pumpAndSettle();

        expect(stored('1').status, status);
        expect((sheet(), hint(), action()), before, reason: '$status');
      }
    },
  );

  testWidgets(
    'should refuse a hint over 20 characters counted as the domain does',
    (tester) async {
      await holdTile(tester, '5');
      final field = find.byKey(const Key('house.comeBackHint.field'));
      final count = find.byKey(const Key('house.comeBackHint.count'));
      expect(tester.widget<Text>(count).data, '9/20');

      // 16 letters and the emoji: 17 symbols, 21 code points.
      await tester.enterText(field, '${'a' * 16}$_family');
      await tester.pump();

      expect(find.text('après 19h'), findsOneWidget);
      expect(find.text('Précision limitée à 20 caractères.'), findsOneWidget);
      expect(tester.widget<Text>(count).data, '9/20');

      final longest = '${'a' * 15}$_family';
      await tester.enterText(field, longest);
      await tester.pump();

      expect(find.text('Précision limitée à 20 caractères.'), findsNothing);
      expect(tester.widget<Text>(count).data, '20/20');

      await closeSheet(tester);

      expect(stored('5').comeBack, comeBack(longest));
    },
  );
}
