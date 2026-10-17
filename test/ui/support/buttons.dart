import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether the button under the widget [button] (a `PrimaryButton`, a
/// `SecondaryButton`…) can be pressed. Material buttons are all
/// `ButtonStyleButton`s, disabled when `onPressed` is null.
bool isEnabled(WidgetTester tester, Finder button) => tester
    .widget<ButtonStyleButton>(
      find.descendant(
        of: button,
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    )
    .enabled;

/// Scrolls the screen's `CustomScrollView` until [finder] is in sight,
/// then taps it: a long screen builds what is below the fold of the
/// test's 800 × 600 window only once scrolled to.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  // Whole, not only its first pixels.
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}
