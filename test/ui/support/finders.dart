import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/components/arrow_text.dart';

/// Finds the message [text] (« 7 → Fait ») shown by an `ArrowText`.
///
/// `find.text` cannot: the arrow is drawn, not written, so the text on
/// screen holds a placeholder where the « → » was.
Finder findArrowText(String text) => find.byWidgetPredicate(
  (widget) => widget is ArrowText && widget.text == text,
  description: 'ArrowText "$text"',
);
