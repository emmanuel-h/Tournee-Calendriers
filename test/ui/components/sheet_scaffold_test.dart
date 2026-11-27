import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_theme.dart';

void main() {
  // The bottom of the screen is 800 dp; the last child's bottom edge must
  // stay above the navigation bar (or the keyboard) with 28 dp to spare.
  Future<double> lastChildBottom(
    WidgetTester tester, {
    double navigationBar = 0,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(bottom: navigationBar),
              viewPadding: EdgeInsets.only(bottom: navigationBar),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            // A modal sheet sits over the screen, not in a Scaffold that
            // shrinks for the keyboard: only the sheet's own padding counts.
            child: const Scaffold(
              resizeToAvoidBottomInset: false,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SheetScaffold(
                  children: [SizedBox(key: Key('last'), height: 40)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return tester.getBottomLeft(find.byKey(const Key('last'))).dy;
  }

  testWidgets(
    'should keep the last child above the navigation bar when it has buttons',
    (tester) async {
      expect(await lastChildBottom(tester, navigationBar: 48), 800 - 48 - 28);
    },
  );

  testWidgets(
    'should keep the last child above the keyboard alone when it covers the bar',
    (tester) async {
      expect(
        await lastChildBottom(tester, navigationBar: 48, keyboard: 300),
        800 - 300 - 28,
      );
    },
  );

  testWidgets('should keep 28 dp at the bottom when there is no bar', (
    tester,
  ) async {
    expect(await lastChildBottom(tester), 800 - 28);
  });
}
