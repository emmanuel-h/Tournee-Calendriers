import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the phone's clipboard during a widget test.
///
/// `Clipboard.setData` sends a message on the platform channel to Android;
/// in a test nobody answers it. This handler answers instead and keeps the
/// text, so the test can read what was copied in [text].
final class FakeClipboard {
  FakeClipboard._();

  /// The text last copied, `null` while nothing was.
  String? text;

  /// Installs the fake for the current test; it is removed when the test
  /// ends.
  static FakeClipboard install(WidgetTester tester) {
    final clipboard = FakeClipboard._();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.text =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return clipboard;
  }
}
