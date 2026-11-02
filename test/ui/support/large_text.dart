import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's fonts, as `pubspec.yaml` declares them.
const _fonts = {
  'Atkinson Hyperlegible': [
    'assets/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.ttf',
    'assets/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Bold.ttf',
  ],
  'Barlow Condensed': [
    'assets/fonts/barlow_condensed/BarlowCondensed-SemiBold.ttf',
    'assets/fonts/barlow_condensed/BarlowCondensed-Bold.ttf',
  ],
};

/// Loads the app's real fonts into the test engine.
///
/// Widget tests draw text in a test font whose every letter is a square as
/// wide as the font size: about twice as wide as Barlow Condensed. Whether
/// a line holds at 200 % can only be told with the real letters. Call it
/// from `setUpAll` of the large-text group, the last of its file: it
/// changes text widths for every test run after it in the same file.
Future<void> loadAppFonts() async {
  for (final MapEntry(key: family, value: files) in _fonts.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File(file).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// Shows the next screens as a phone with Android's largest font size
/// would: a 411 × 914 dp screen (1080 × 2400 px) and text drawn at 200 %
/// (`TextScaler.linear(2.0)`). A row that cannot hold its text then
/// throws « A RenderFlex overflowed », which fails the test.
void useLargeText(WidgetTester tester) {
  usePhoneScreen(tester);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  // The test binding is shared by every test of the file: put it back.
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Shows the next screens on the same 411 × 914 dp phone as
/// [useLargeText], with text at its normal size: the 100 % side of a
/// layout that changes with the font size.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

/// Checks what TalkBack and a finger need of the screen shown: every
/// control that answers a tap has a label, and, unless [tapTargets] is
/// false, is at least 48 × 48 dp (Android's guidelines, as Flutter's test
/// tools measure them).
Future<void> expectAccessibleControls(
  WidgetTester tester, {
  bool tapTargets = true,
}) async {
  final semantics = tester.ensureSemantics();
  await tester.pumpAndSettle();
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  if (tapTargets) {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  }
  semantics.dispose();
}
