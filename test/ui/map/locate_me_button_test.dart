import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/ui/map/locate_me_button.dart';
import 'package:tournee_calendriers/ui/map/phone_location.dart';

import '../../support/geo_fixtures.dart';
import '../support/test_app.dart';
import 'fake_phone_location.dart';

final _townHall = at(45.98915, 4.71862);
final _button = find.byKey(const Key('map.locateMe'));

void main() {
  late List<GeoPoint> located;

  setUp(() => located = []);

  Future<void> pumpButton(WidgetTester tester, FakePhoneLocation phone) =>
      tester.pumpWidget(
        testApp(
          Center(
            child: LocateMeButton(phone: phone, onLocated: located.add),
          ),
        ),
      );

  testWidgets('should not touch the location when the button is only shown', (
    tester,
  ) async {
    final phone = FakePhoneLocation(accessNow: LocationAccess.denied);

    await pumpButton(tester, phone);

    expect(phone.calls, isEmpty);
    expect(tester.getSize(_button), const Size(48, 48));
    expect(find.bySemanticsLabel('Me localiser'), findsOneWidget);
  });

  testWidgets(
    'should ask for the access, then hand over the position, on the first tap',
    (tester) async {
      final phone = FakePhoneLocation(
        accessNow: LocationAccess.denied,
        position: _townHall,
      );
      await pumpButton(tester, phone);

      await tester.tap(_button);
      await tester.pump();

      expect(phone.calls, contains('requestAccess'));
      expect(located, [_townHall]);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('should show a spinner and ignore taps while the fix is coming', (
    tester,
  ) async {
    final fix = Completer<GeoPoint?>();
    final phone = FakePhoneLocation()..pendingFix = fix;
    await pumpButton(tester, phone);

    await tester.tap(_button);
    await tester.pump();
    await tester.tap(_button);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.gps_not_fixed), findsNothing);
    expect(
      phone.calls.where((call) => call == 'currentPosition'),
      hasLength(1),
    );

    fix.complete(_townHall);
    await tester.pump();

    expect(located, [_townHall]);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.gps_not_fixed), findsOneWidget);
  });

  testWidgets('should say to allow it when the user refuses the dialog', (
    tester,
  ) async {
    final phone = FakePhoneLocation(
      accessNow: LocationAccess.denied,
      answer: LocationAccess.denied,
    );
    await pumpButton(tester, phone);

    await tester.tap(_button);
    await tester.pump();

    expect(
      find.text('Autorisez la localisation pour vous situer sur la carte.'),
      findsOneWidget,
    );
    expect(located, isEmpty);
  });

  testWidgets(
    'should offer the settings when the access was refused for good',
    (tester) async {
      final phone = FakePhoneLocation(accessNow: LocationAccess.deniedForever);
      await pumpButton(tester, phone);

      await tester.tap(_button);
      await tester.pump();
      expect(
        find.text(
          'La localisation est refusée pour l\'application. '
          'Autorisez-la dans les réglages.',
        ),
        findsOneWidget,
      );
      // The snackbar slides in before its action can be tapped.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réglages'));

      expect(phone.calls.last, 'openSettings');
      expect(located, isEmpty);
    },
  );

  testWidgets('should say the location is off when the service is off', (
    tester,
  ) async {
    final phone = FakePhoneLocation(serviceEnabled: false);
    await pumpButton(tester, phone);

    await tester.tap(_button);
    await tester.pump();

    expect(
      find.text('La localisation du téléphone est désactivée.'),
      findsOneWidget,
    );
    expect(located, isEmpty);
  });

  testWidgets('should say no position came when the phone has no fix', (
    tester,
  ) async {
    final phone = FakePhoneLocation();
    await pumpButton(tester, phone);

    await tester.tap(_button);
    await tester.pump();

    expect(
      find.text(
        'Position introuvable pour l\'instant. Réessayez dans un moment.',
      ),
      findsOneWidget,
    );
    expect(located, isEmpty);
  });

  testWidgets('should not hand over a position once the button is gone', (
    tester,
  ) async {
    final fix = Completer<GeoPoint?>();
    final phone = FakePhoneLocation()..pendingFix = fix;
    await pumpButton(tester, phone);
    await tester.tap(_button);
    await tester.pump();

    await tester.pumpWidget(testApp(const SizedBox()));
    fix.complete(_townHall);
    await tester.pump();

    expect(located, isEmpty);
  });
}
