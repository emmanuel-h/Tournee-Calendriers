import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Types [text] in [field], then presses the keyboard's « OK » (the
/// `TextInputAction.done` key), as a person does to validate.
Future<void> typeAndSubmit(
  WidgetTester tester,
  Finder field,
  String text,
) async {
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Whether the text field [field] has the focus, so the keyboard stays
/// open on it. The focus belongs to the `EditableText` inside a
/// `TextField`.
bool hasFocus(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;
